import { expect } from 'chai';
import { ethers } from 'hardhat';
import { loadFixture } from '@nomicfoundation/hardhat-toolbox/network-helpers';
import { AgentHiringContract } from '../typechain-types';
import { SignerWithAddress } from '@nomicfoundation/hardhat-ethers/signers';

describe('AgentHiringContract', function () {
  async function deployContractFixture() {
    const [owner, agent, user] = await ethers.getSigners();

    // 使用 Sepolia USDT 地址
    const USDT_ADDRESS = '0xaA8E23Fb1079EA71e0a56F48a2aA51851D8433D0';

    const AgentHiringContract = await ethers.getContractFactory(
      'AgentHiringContract'
    );
    const agentHiring = await AgentHiringContract.deploy(USDT_ADDRESS);

    return { agentHiring, owner, agent, user, USDT_ADDRESS };
  }

  describe('Deployment', function () {
    it('Should set the right owner', async function () {
      const { agentHiring, owner } = await loadFixture(deployContractFixture);
      expect(await agentHiring.owner()).to.equal(owner.address);
    });

    it('Should set the right USDT address', async function () {
      const { agentHiring, USDT_ADDRESS } = await loadFixture(
        deployContractFixture
      );
      expect(await agentHiring.USDT()).to.equal(USDT_ADDRESS);
    });
  });

  describe('Agent Registration', function () {
    it('Should register a new agent', async function () {
      const { agentHiring, agent } = await loadFixture(deployContractFixture);

      const ratePerDay = ethers.parseUnits('10', 6); // 10 USDT per day (6 decimals)
      await agentHiring.registerAgent(agent.address, 'DEFI', ratePerDay);

      const agentDetails = await agentHiring.getAgentDetails(agent.address);
      expect(agentDetails.agentType).to.equal('DEFI');
      expect(agentDetails.ratePerDay).to.equal(ratePerDay);
      expect(agentDetails.isActive).to.be.true;
    });

    it('Should revert with zero rate', async function () {
      const { agentHiring, agent } = await loadFixture(deployContractFixture);

      await expect(
        agentHiring.registerAgent(agent.address, 'DEFI', 0)
      ).to.be.revertedWithCustomError(agentHiring, 'ZeroRateNotAllowed');
    });

    it('Should not allow registering same agent twice', async function () {
      const { agentHiring, agent } = await loadFixture(deployContractFixture);

      await agentHiring.registerAgent(
        agent.address,
        'DEFI',
        ethers.parseUnits('10', 6)
      );

      await expect(
        agentHiring.registerAgent(
          agent.address,
          'CRYPTO',
          ethers.parseUnits('20', 6)
        )
      ).to.be.revertedWithCustomError(agentHiring, 'AgentAlreadyExists');
    });
  });

  describe('Access Control', function () {
    it('Should only allow owner to register agents', async function () {
      const { agentHiring, agent, user } = await loadFixture(
        deployContractFixture
      );

      await expect(
        agentHiring
          .connect(user)
          .registerAgent(agent.address, 'DEFI', ethers.parseUnits('10', 6))
      ).to.be.revertedWithCustomError(
        agentHiring,
        'OwnableUnauthorizedAccount'
      );
    });
  });

  describe('Engagement Management', function () {
    it('Should not allow engagement with inactive agent', async function () {
      const { agentHiring, agent, user } = await loadFixture(
        deployContractFixture
      );

      await expect(
        agentHiring.connect(user).createEngagement(agent.address, 1)
      ).to.be.revertedWithCustomError(agentHiring, 'AgentNotActive');
    });
  });
});
