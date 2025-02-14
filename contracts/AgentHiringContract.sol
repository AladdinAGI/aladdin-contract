// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/access/Ownable.sol"; 
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title AgentHiringContract
 * @dev Contract for managing agent hiring and payment processes with USDT
 * 使用USDT进行支付的Agent雇佣管理合约
 */
contract AgentHiringContract is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /**
     * @dev Agent structure containing all agent information
     * Agent结构体，包含所有Agent信息
     */
    struct Agent {
        address walletAddress;  // Agent's wallet address | Agent的钱包地址
        string agentType;       // Agent type (e.g., "DEFI", "CRYPTO") | Agent类型（如"DEFI"、"CRYPTO"）
        uint256 ratePerDay;     // Daily rate for hiring (in USDT, 6 decimals) | 每日雇佣费率（USDT，6位小数）
        bool isActive;          // Whether the agent is active | Agent是否处于活跃状态
        uint256 totalEarnings;  // Total earnings in USDT | Agent的USDT总收入
    }

    /**
     * @dev Engagement structure representing a hiring relationship
     * 雇佣关系结构体，表示一个雇佣关系
     */
    struct Engagement {
        address user;           // Address of the hiring user | 雇主地址
        address agent;          // Address of the hired agent | 被雇佣的Agent地址
        uint256 startTime;      // Start time of the engagement | 雇佣开始时间
        uint256 duration;       // Duration in days | 雇佣持续时间（天）
        uint256 payment;        // Total payment amount in USDT | USDT支付总额
        bool isActive;          // Whether the engagement is active | 雇佣关系是否活跃
        bool isCompleted;       // Whether the engagement is completed | 雇佣关系是否完成
    }

    // USDT contract address | USDT合约地址
    IERC20 public immutable USDT;
    
    // Mapping from address to Agent | 地址到Agent的映射
    mapping(address => Agent) public agents;
    // Mapping from ID to Engagement | ID到雇佣关系的映射
    mapping(uint256 => Engagement) public engagements;
    // Counter for engagement IDs | 雇佣关系ID计数器
    uint256 public engagementCount;

    /**
     * @dev Events for contract activities
     * 合约活动事件
     */
    event AgentRegistered(address indexed agentAddress, string agentType, uint256 ratePerDay);
    event EngagementCreated(uint256 indexed engagementId, address user, address agent, uint256 payment);
    event EngagementCompleted(uint256 indexed engagementId, uint256 payment);
    event PaymentReleased(address indexed agent, uint256 amount);

    /**
     * @dev Custom errors for the contract
     * 合约自定义错误
     */
    error AgentAlreadyExists();        // Agent already registered | Agent已注册
    error AgentNotActive();            // Agent is not active | Agent未激活
    error InsufficientUSDT();          // Insufficient USDT balance | USDT余额不足
    error InsufficientAllowance();     // Insufficient USDT allowance | USDT授权额度不足
    error EngagementNotActive();       // Engagement is not active | 雇佣关系未激活
    error EngagementAlreadyCompleted();// Engagement already completed | 雇佣关系已完成
    error NotAuthorized();             // Caller not authorized | 调用者未授权
    error InvalidUSDTAddress();        // Invalid USDT address | 无效的USDT地址
    error ZeroRateNotAllowed();        // Zero rate not allowed | 不允许零费率

    /**
     * @dev Constructor to initialize the contract with USDT
     * 构造函数，初始化USDT合约地址
     * @param _usdt USDT contract address | USDT合约地址
     */
    constructor(address _usdt) Ownable(msg.sender) {
        if(_usdt == address(0)) revert InvalidUSDTAddress();
        USDT = IERC20(_usdt);
    }

    /**
     * @dev Register a new agent with USDT rate
     * 注册新的Agent（USDT计费）
     * @param agentAddress Address of the agent | Agent地址
     * @param agentType Type of the agent | Agent类型
     * @param ratePerDay Daily rate in USDT (6 decimals) | Agent的每日USDT费率（6位小数）
     */
    function registerAgent(
        address agentAddress,
        string calldata agentType,
        uint256 ratePerDay
    ) external onlyOwner {
        if(agents[agentAddress].walletAddress != address(0)) {
            revert AgentAlreadyExists();
        }
        if(ratePerDay == 0) {
            revert ZeroRateNotAllowed();
        }
        
        agents[agentAddress] = Agent({
            walletAddress: agentAddress,
            agentType: agentType,
            ratePerDay: ratePerDay,
            isActive: true,
            totalEarnings: 0
        });

        emit AgentRegistered(agentAddress, agentType, ratePerDay);
    }

    /**
     * @dev Create a new engagement with USDT payment
     * 创建新的雇佣关系（USDT支付）
     * @param agentAddress Address of the agent to hire | 要雇佣的Agent地址
     * @param duration Duration of the engagement in days | 雇佣持续时间（天）
     */
    function createEngagement(
        address agentAddress,
        uint256 duration
    ) external nonReentrant {
        if(!agents[agentAddress].isActive) {
            revert AgentNotActive();
        }
        
        uint256 payment = agents[agentAddress].ratePerDay * duration;
        
        if(USDT.balanceOf(msg.sender) < payment) {
            revert InsufficientUSDT();
        }
        if(USDT.allowance(msg.sender, address(this)) < payment) {
            revert InsufficientAllowance();
        }

        // Transfer USDT from user to contract | 将USDT从用户转到合约
        USDT.safeTransferFrom(msg.sender, address(this), payment);

        uint256 engagementId = engagementCount++;
        engagements[engagementId] = Engagement({
            user: msg.sender,
            agent: agentAddress,
            startTime: block.timestamp,
            duration: duration,
            payment: payment,
            isActive: true,
            isCompleted: false
        });

        emit EngagementCreated(engagementId, msg.sender, agentAddress, payment);
    }

    /**
     * @dev Complete an engagement and release USDT payment
     * 完成雇佣关系并释放USDT支付
     * @param engagementId ID of the engagement to complete | 要完成的雇佣关系ID
     */
    function completeEngagement(uint256 engagementId) external nonReentrant {
        Engagement storage engagement = engagements[engagementId];
        
        if(!engagement.isActive) {
            revert EngagementNotActive();
        }
        if(engagement.isCompleted) {
            revert EngagementAlreadyCompleted();
        }
        if(msg.sender != engagement.agent && msg.sender != owner()) {
            revert NotAuthorized();
        }

        engagement.isCompleted = true;
        engagement.isActive = false;

        agents[engagement.agent].totalEarnings += engagement.payment;

        // Transfer USDT to agent | 将USDT转给Agent
        USDT.safeTransfer(engagement.agent, engagement.payment);

        emit EngagementCompleted(engagementId, engagement.payment);
        emit PaymentReleased(engagement.agent, engagement.payment);
    }

    /**
     * @dev Get agent details including USDT earnings
     * 获取Agent详情（包括USDT收入）
     * @param agentAddress Address of the agent | Agent地址
     */
    function getAgentDetails(address agentAddress) external view returns (
        string memory agentType,
        uint256 ratePerDay,
        bool isActive,
        uint256 totalEarnings
    ) {
        Agent memory agent = agents[agentAddress];
        return (
            agent.agentType,
            agent.ratePerDay,
            agent.isActive,
            agent.totalEarnings
        );
    }
}