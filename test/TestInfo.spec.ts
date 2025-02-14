import { expect } from 'chai';
import hre from 'hardhat';
import { loadFixture } from '@nomicfoundation/hardhat-toolbox/network-helpers';

describe('TestInfo', function () {
  // 定义一个基础的部署fixture
  async function deployTestInfoFixture() {
    // 获取测试账户
    const [owner, otherAccount] = await hre.ethers.getSigners();

    // 部署合约
    const TestInfo = await hre.ethers.getContractFactory('TestInfo');
    const testInfo = await TestInfo.deploy();

    return { testInfo, owner, otherAccount };
  }

  describe('Deployment', function () {
    it('Should set the right owner', async function () {
      const { testInfo, owner } = await loadFixture(deployTestInfoFixture);
      expect(await testInfo.owner()).to.equal(owner.address);
    });

    it('Should set the initial info', async function () {
      const { testInfo } = await loadFixture(deployTestInfoFixture);
      expect(await testInfo.getInfo()).to.equal('Initial Info');
    });
  });

  describe('Operations', function () {
    describe('Set Info', function () {
      it('Should allow owner to set info', async function () {
        const { testInfo } = await loadFixture(deployTestInfoFixture);
        await testInfo.setInfo('New Test Info');
        expect(await testInfo.getInfo()).to.equal('New Test Info');
      });

      it('Should emit InfoChanged event', async function () {
        const { testInfo } = await loadFixture(deployTestInfoFixture);
        await expect(testInfo.setInfo('New Test Info'))
          .to.emit(testInfo, 'InfoChanged')
          .withArgs('New Test Info');
      });

      it('Should revert if called by non-owner', async function () {
        const { testInfo, otherAccount } = await loadFixture(
          deployTestInfoFixture
        );
        await expect(
          testInfo.connect(otherAccount).setInfo('Unauthorized Info')
        ).to.be.revertedWith('Only owner can set info');
      });
    });

    describe('Get Info', function () {
      it('Should return the correct info', async function () {
        const { testInfo } = await loadFixture(deployTestInfoFixture);
        await testInfo.setInfo('Test Info');
        expect(await testInfo.getInfo()).to.equal('Test Info');
      });
    });
  });
});
