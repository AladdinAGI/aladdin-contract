import { ethers, run } from 'hardhat';

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log('Deploying contracts with account:', deployer.address);

  // Sepolia USDT address
  const USDT_ADDRESS = '0xaA8E23Fb1079EA71e0a56F48a2aA51851D8433D0';

  // Deploy AgentHiringContract
  const AgentHiringContract = await ethers.getContractFactory(
    'AgentHiringContract'
  );
  const agentHiring = await AgentHiringContract.deploy(USDT_ADDRESS);
  await agentHiring.waitForDeployment();

  const contractAddress = await agentHiring.getAddress();
  console.log('AgentHiringContract deployed to:', contractAddress);

  // 等待几个区块确认后再验证
  console.log('Waiting for blocks confirmations...');
  await agentHiring.deploymentTransaction()?.wait(5);

  // 验证合约
  console.log('Verifying contract...');
  try {
    await run('verify:verify', {
      address: contractAddress,
      constructorArguments: [USDT_ADDRESS],
    });
    console.log('Contract verified successfully');
  } catch (error: any) {
    if (error.message.toLowerCase().includes('already verified')) {
      console.log('Contract is already verified!');
    } else {
      console.log('Error verifying contract:', error);
    }
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
