pragma solidity ^0.8.10;

interface IGoober {
    event Approval(address indexed owner, address indexed spender, uint256 amount);
    event Deposit(address indexed caller, address indexed receiver, uint256[] gobblers, uint256 gooTokens, uint256 fractions);
    event FeesAccrued(address indexed feeTo, uint256 fractions, bool performanceFee, uint256 _deltaK);
    event Swap(
        address indexed caller,
        address indexed receiver,
        uint256 gooTokensIn,
        uint256 gobblersMultIn,
        uint256 gooTokensOut,
        uint256 gobblerMultOut
    );
    event Sync(uint256 gooBalance, uint256 multBalance);
    event Transfer(address indexed from, address indexed to, uint256 amount);
    event VaultMint(address indexed minter, uint256 auctionPricePerMult, uint256 poolPricePerMult, uint256 gooConsumed);
    event Withdraw(
        address indexed caller, address indexed receiver, address indexed owner, uint256[] gobblers, uint256 gooTokens, uint256 fractions
    );

    function DOMAIN_SEPARATOR() external view returns (bytes32);
    function MANAGEMENT_FEE_BPS() external view returns (uint16);
    function PERFORMANCE_FEE_BPS() external view returns (uint16);
    function allowance(address, address) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function artGobblers() external view returns (address);
    function balanceOf(address) external view returns (uint256);
    function blockTimestampLast() external view returns (uint32);
    function convertToAssets(uint256 fractions) external view returns (uint256 gooTokens, uint256 gobblerMult);
    function convertToFractions(uint256 gooTokens, uint256 gobblerMult) external view returns (uint256 fractions);
    function decimals() external view returns (uint8);
    function deposit(uint256[] memory gobblers, uint256 gooTokens, address receiver) external returns (uint256 fractions);
    function feeTo() external view returns (address);
    function flagGobbler(uint256 tokenId, bool _flagged) external;
    function flagged(uint256) external view returns (bool);
    function getReserves() external view returns (uint256 _gooReserve, uint256 _gobblerReserve, uint32 _blockTimestampLast);
    function goo() external view returns (address);
    function kDebt() external view returns (uint112);
    function kLast() external view returns (uint112);
    function mintGobbler() external;
    function minter() external view returns (address);
    function name() external view returns (string memory);
    function nonces(address) external view returns (uint256);
    function onERC721Received(address, address, uint256 tokenId, bytes memory) external view returns (bytes4);
    function permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external;
    function previewDeposit(uint256[] memory gobblers, uint256 gooTokens) external view returns (uint256 fractions);
    function previewSwap(uint256[] memory gobblersIn, uint256 gooIn, uint256[] memory gobblersOut, uint256 gooOut)
        external
        view
        returns (int256 erroneousGoo);
    function previewWithdraw(uint256[] memory gobblers, uint256 gooTokens) external view returns (uint256 fractions);
    function priceGobblerCumulativeLast() external view returns (uint256);
    function priceGooCumulativeLast() external view returns (uint256);
    function safeDeposit(uint256[] memory gobblers, uint256 gooTokens, address receiver, uint256 minFractionsOut, uint256 deadline)
        external
        returns (uint256 fractions);
    function safeSwap(
        uint256 erroneousGooAbs,
        uint256 deadline,
        uint256[] memory gobblersIn,
        uint256 gooIn,
        uint256[] memory gobblersOut,
        uint256 gooOut,
        address receiver,
        bytes memory data
    ) external returns (int256 erroneousGoo);
    function safeWithdraw(
        uint256[] memory gobblers,
        uint256 gooTokens,
        address receiver,
        address owner,
        uint256 maxFractionsIn,
        uint256 deadline
    ) external returns (uint256 fractions);
    function setFeeTo(address newFeeTo) external;
    function setMinter(address newMinter) external;
    function skim(address erc20) external;
    function swap(
        uint256[] memory gobblersIn,
        uint256 gooIn,
        uint256[] memory gobblersOut,
        uint256 gooOut,
        address receiver,
        bytes memory data
    ) external returns (int256);
    function symbol() external view returns (string memory);
    function totalAssets() external view returns (uint256 gooTokens, uint256 gobblerMult);
    function totalSupply() external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function withdraw(uint256[] memory gobblers, uint256 gooTokens, address receiver, address owner) external returns (uint256 fractions);
}
