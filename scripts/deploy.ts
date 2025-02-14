import { ethers } from 'hardhat';

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log('Deploying contracts with the account:', deployer.address);

  const TestInfo = await ethers.getContractFactory('TestInfo');
  const testInfo = await TestInfo.deploy();
  await testInfo.waitForDeployment();

  const address = await testInfo.getAddress();
  console.log('TestInfo contract deployed to:', address);

  // 输出初始信息
  const initialInfo = await testInfo.getInfo();
  console.log('Initial info:', initialInfo);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
