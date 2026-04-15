// scripts/deploy.js
// Deployment script for AgentCourt on X Layer.
//
// Run against testnet:  npx hardhat run scripts/deploy.js --network xlayer_testnet
// Run against mainnet:  npx hardhat run scripts/deploy.js --network xlayer_mainnet
// Run locally:          npx hardhat run scripts/deploy.js --network localhost

const { ethers } = require("hardhat");

// ---------------------------------------------------------------------------
// Arbitrator addresses — replace with real multisig / EOA addresses before
// deploying to mainnet.
// ---------------------------------------------------------------------------
const ARBITRATORS = [
  "0x1111111111111111111111111111111111111111",
  "0x2222222222222222222222222222222222222222",
  "0x3333333333333333333333333333333333333333",
];

async function main() {
  const [deployer] = await ethers.getSigners();

  console.log("=".repeat(60));
  console.log("AgentCourt — Deployment Script");
  console.log("=".repeat(60));
  console.log(`Deployer : ${deployer.address}`);
  console.log(`Network  : ${(await ethers.provider.getNetwork()).name}`);
  console.log(`Balance  : ${ethers.formatEther(await ethers.provider.getBalance(deployer.address))} OKB`);
  console.log("-".repeat(60));

  // -------------------------------------------------------------------------
  // Step 1 — Deploy AgentReputation
  // -------------------------------------------------------------------------
  console.log("\n[1/5] Deploying AgentReputation...");
  const AgentReputation = await ethers.getContractFactory("AgentReputation");
  const agentReputation = await AgentReputation.deploy();
  await agentReputation.waitForDeployment();
  const reputationAddr = await agentReputation.getAddress();
  console.log(`      AgentReputation deployed at: ${reputationAddr}`);

  // -------------------------------------------------------------------------
  // Step 2 — Deploy DisputeRegistry (needs AgentReputation address)
  // -------------------------------------------------------------------------
  console.log("\n[2/5] Deploying DisputeRegistry...");
  const DisputeRegistry = await ethers.getContractFactory("DisputeRegistry");
  const disputeRegistry = await DisputeRegistry.deploy(reputationAddr);
  await disputeRegistry.waitForDeployment();
  const registryAddr = await disputeRegistry.getAddress();
  console.log(`      DisputeRegistry deployed at: ${registryAddr}`);

  // -------------------------------------------------------------------------
  // Step 3 — Deploy ArbitratorPool (needs 3 arb addresses + DisputeRegistry)
  // -------------------------------------------------------------------------
  console.log("\n[3/5] Deploying ArbitratorPool...");
  console.log(`      Arbitrators:`);
  ARBITRATORS.forEach((a, i) => console.log(`        [${i}] ${a}`));

  const ArbitratorPool = await ethers.getContractFactory("ArbitratorPool");
  const arbitratorPool = await ArbitratorPool.deploy(
    ARBITRATORS[0],
    ARBITRATORS[1],
    ARBITRATORS[2],
    registryAddr
  );
  await arbitratorPool.waitForDeployment();
  const poolAddr = await arbitratorPool.getAddress();
  console.log(`      ArbitratorPool deployed at: ${poolAddr}`);

  // -------------------------------------------------------------------------
  // Step 4 — Wire: AgentReputation → DisputeRegistry
  // -------------------------------------------------------------------------
  console.log("\n[4/5] Wiring AgentReputation.setDisputeRegistry()...");
  const tx4 = await agentReputation.setDisputeRegistry(registryAddr);
  await tx4.wait();
  console.log(`      Done (tx: ${tx4.hash})`);

  // -------------------------------------------------------------------------
  // Step 5 — Wire: DisputeRegistry → ArbitratorPool
  // -------------------------------------------------------------------------
  console.log("\n[5/5] Wiring DisputeRegistry.setArbitratorPool()...");
  const tx5 = await disputeRegistry.setArbitratorPool(poolAddr);
  await tx5.wait();
  console.log(`      Done (tx: ${tx5.hash})`);

  // -------------------------------------------------------------------------
  // Summary
  // -------------------------------------------------------------------------
  console.log("\n" + "=".repeat(60));
  console.log("Deployment complete — contract addresses");
  console.log("=".repeat(60));
  console.log(`AgentReputation  : ${reputationAddr}`);
  console.log(`DisputeRegistry  : ${registryAddr}`);
  console.log(`ArbitratorPool   : ${poolAddr}`);
  console.log("=".repeat(60));
  console.log("\nNext steps:");
  console.log("  • Verify contracts on the X Layer explorer");
  console.log("  • Replace placeholder arbitrator addresses with real ones");
  console.log("  • Fund DisputeRegistry if you want pre-seeded compensation pools");
}

main().catch((err) => {
  console.error(err);
  process.exitCode = 1;
});
