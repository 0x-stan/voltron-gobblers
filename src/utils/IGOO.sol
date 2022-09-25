// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

interface IGOO {
    event Approval(address indexed owner, address indexed spender, uint256 amount);
    event Transfer(address indexed from, address indexed to, uint256 amount);

    function DOMAIN_SEPARATOR() view external returns (bytes32);
    function allowance(address, address) view external returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function artGobblers() view external returns (address);
    function balanceOf(address) view external returns (uint256);
    function burnForGobblers(address from, uint256 amount) external;
    function burnForPages(address from, uint256 amount) external;
    function decimals() view external returns (uint8);
    function mintForGobblers(address to, uint256 amount) external;
    function name() view external returns (string memory);
    function nonces(address) view external returns (uint256);
    function pages() view external returns (address);
    function permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external;
    function symbol() view external returns (string memory);
    function totalSupply() view external returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}