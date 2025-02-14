// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

contract TestInfo {
    string private info;
    address public owner;

    event InfoChanged(string newInfo);

    constructor() {
        owner = msg.sender;
        info = "Initial Info";
    }

    function setInfo(string memory _info) public {
        require(msg.sender == owner, "Only owner can set info");
        info = _info;
        emit InfoChanged(_info);
    }

    function getInfo() public view returns (string memory) {
        return info;
    }
}