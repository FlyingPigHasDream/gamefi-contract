
pragma solidity ^0.7.3;

import "./IERC721.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {SafeMath} from "@openzeppelin/contracts/math/SafeMath.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
 
interface IMarketPlace {

    event MarketTransaction(string TxType, address owner, uint256 tokenId);
    event MonetaryTransaction(string message, address recipient, uint256 amount);

    /**
    * Set the current contract address and initialize the instance of the contract.
    * Requirement: Only the contract owner can call.
     */
    function setContract(address _contractAddress) external;

    /**
    * Sets status of _paused to true which affects all functions that have whenNotPaused modifiers.
     */
    function pause() external;

    /**
    * Sets status of _paused to false which affects all functions that have whenNotPaused modifiers.
     */
    function resume() external;

    /**
    * Get the details about a offer for _tokenId. Throws an error if there is no active offer for _tokenId.
     */
    function getOffer(uint256 _tokenId) external view returns (address seller, uint256 price, uint256 index, uint256 tokenId, bool active);

    /**
    * Get all tokenId's that are currently for sale. Returns an empty array if no offer exists.
     */
    function getAllTokensOnSale() external view returns (uint256[] memory listOfOffers);

    /**
    * Creates a new offer for _tokenId for the price _price.
    * Emits the MarketTransaction event with txType "Create offer"
    * Requirement: Only the owner of _tokenId can create an offer.
    * Requirement: There can only be one active offer for a token at a time.
    * Requirement: Marketplace contract (this) needs to be an approved operator when the offer is created.
     */
    function setOffer(uint256 _price, uint256 _tokenId) external;

    /**
    * Removes an existing offer.
    * Emits the MarketTransaction event with txType "Remove offer"
    * Requirement: Only the seller of _tokenId can remove an offer.
     */
    function removeOffer(uint256 _tokenId) external;

    /**
    * Executes the purchase of _tokenId.
    * Transfers the token using transferFrom in CryptoLittleGuiies.
    * Transfers funds to the _fundsToBeCollected mapping.
    * Removes the offer from the mapping.
    * Sets the offer in the array to inactive.
    * Emits the MarketTransaction event with txType "Buy".
    * Requirement: The msg.value needs to equal the price of _tokenId
    * Requirement: There must be an active offer for _tokenId
     */
    function buyLittleGui(uint256 _tokenId) external payable;

    /**
    * Returns current balance of msg.sender
     */
    function getBalance() external view returns (uint256);

    /**
    * Send funds to msg.sender.
    * Emits a MonetaryTransaction event "Successful Transfer".
    * Requirement: msg.sender must have funds in the mapping.
     */
    function withdrawFunds() external payable;
}


/*
 * Market place to trade little-guis (should **in theory** be used for any ERC721 token)
 * It needs an existing little-gui contract to interact with
 * Note: it does not inherit from the contract
 * Note: It takes ownership of the little-gui for the duration that is is on the marketplace.
 */

contract MarketPlace is Ownable  {

    uint256 public feePercent = 1; // 1% fee
    address private feeAddress; //收取交易手续费的地址

    IERC721 private _littleGui;
    IERC20 public _payToken;

    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    struct Offer {
        address seller;
        uint256 price;
        uint256 index;
        uint256 tokenId;
        bool active;
    }

    bool internal _paused;
   
    Offer[] offers;

    mapping(uint256 => Offer) tokenIdToOffer;

    mapping (address => uint256[])  addressToIds;
    
    event MarketTransaction(string TxType, address owner, uint256 tokenId);
    event MarketUpdate(string TxType, address owner, uint256 tokenId);
    
    //Contract can be paused by owner to ensure bugs can be fixed after deployment
    modifier whenNotPaused() {
        require(!_paused);
        _;
    }

    modifier whenPaused() {
        require(_paused);
        _;
    }
 

    function setContract(address _nftAddress, address _payAddress) onlyOwner public {
        _littleGui = IERC721(_nftAddress);
        _payToken = IERC20(_payAddress);
    }

    constructor(address _nftAddress, address _payAddress) public {
        setContract(_nftAddress,_payAddress);
        _paused = false;
    }

    function pause() public onlyOwner whenNotPaused {
        _paused = true;
    }

    function resume() public onlyOwner whenPaused {
        _paused = false;
    }

    function isPaused() public view returns (bool) {
        return _paused;
    }


    function setFeePercent(uint256 _feePercent) external onlyOwner {
        feePercent = _feePercent;
    }

    function setFeeAddress(address _feeAddress) external onlyOwner {
        feeAddress = _feeAddress;
    }

    function getOffer(uint256 _tokenId) public view returns (
        address seller, 
        uint256 price, 
        uint256 index, 
        uint256 tokenId, 
        bool active) {
        
        require(tokenIdToOffer[_tokenId].active == true, "No active offer at this time");
        
        return (tokenIdToOffer[_tokenId].seller,
                tokenIdToOffer[_tokenId].price,
                tokenIdToOffer[_tokenId].index,
                tokenIdToOffer[_tokenId].tokenId,
                tokenIdToOffer[_tokenId].active);
    }

    function getAllTokensOnSale() public view returns (uint256[] memory listOfOffers) {
        uint256 resultId = 0;//index for all little-guis with active offer status (true)
        
        for (uint256 index = 0; index < offers.length; index++) {
            if (offers[index].active == true && _ownsNFT(offers[index].seller, offers[index].tokenId) ) {
                resultId = SafeMath.add(resultId, 1);//determine length of array to return
            }
        }
        
        if (resultId == 0) {
            return new uint256[](0);//returns empty array
        } else {
            uint256[] memory allTokensOnSale = new uint256[](resultId);
            //initialize new array with correct length
            resultId = 0;//reset index of new array
            for (uint256 index = 0; index < offers.length; index++) {//iterate through entire offers array
                if (offers[index].active == true && _ownsNFT(offers[index].seller, offers[index].tokenId) ) {
                    allTokensOnSale[resultId] = offers[index].tokenId;
                    resultId = SafeMath.add(resultId, 1);
                }
            }
        return allTokensOnSale;
        }
    }


    function getTokensOnSale(address _address) public view returns (uint256[] memory listOfOffers) {
        uint256 resultId = 0; 
        
        uint256[] storage _ids = addressToIds[_address];
        for (uint256 index = 0; index < _ids.length; index++) {
            if (tokenIdToOffer[_ids[index]].active == true && _ownsNFT(_address,_ids[index])) {
                resultId = SafeMath.add(resultId, 1);//determine length of array to return
            }
        }
        
        if (resultId == 0) {
            return new uint256[](0);//returns empty array
        } else {
            uint256[] memory tokensOnSale = new uint256[](resultId);
            //initialize new array with correct length
            resultId = 0;//reset index of new array
            for (uint256 index = 0; index < _ids.length; index++) {//iterate through entire offers array
                if (tokenIdToOffer[_ids[index]].active == true && _ownsNFT(_address,_ids[index])) {
                    tokensOnSale[resultId] = _ids[index];
                    resultId = SafeMath.add(resultId, 1);
                }
            }
        return tokensOnSale;
        }
    }

    function _ownsNFT(address _address, uint256 _tokenId) internal view returns (bool) {
        return (_littleGui.ownerOf(_tokenId) == _address);
    }

    function setOffer(uint256 _price, uint256 _tokenId) public {
        require(_price > 0, "zero!");
        require(_ownsNFT(msg.sender, _tokenId), 
        "Only the owner of the little-gui can initialize an offer");
        require(tokenIdToOffer[_tokenId].active == false, 
        "You already created an offer for this little-gui. Please remove it first before creating a new one.");
        require(_littleGui.isApprovedForAll(msg.sender, address(this)), 
        "MarketPlace contract must first be an approved operator for your little-guis");

        Offer memory _currentOffer = Offer({//set offer
            seller: msg.sender,
            price: _price,
            index: offers.length,
            tokenId: _tokenId,
            active: true
        });

        tokenIdToOffer[_tokenId] = _currentOffer;//update mapping
        offers.push(_currentOffer);//update array
        addressToIds[msg.sender].push(_tokenId);

        emit MarketTransaction("Offer created", msg.sender, _tokenId);
    }
 
    function updateOffer(uint256 _price, uint256 _tokenId) public {
        require(_price > 0, "zero!");
        require(tokenIdToOffer[_tokenId].seller == msg.sender, 
        "Only the owner of the little-gui can update.");

        Offer storage _currentOffer = tokenIdToOffer[_tokenId];
        _currentOffer.price = _price;

        emit MarketUpdate("Offer update", msg.sender, _tokenId);
    }

    function removeOffer(uint256 _tokenId) public {
        require(tokenIdToOffer[_tokenId].seller == msg.sender, 
        "Only the owner of the little-gui can withdraw the offer.");

        offers[tokenIdToOffer[_tokenId].index].active = false;
        //don't iterate through array, simply set active to false.
        delete tokenIdToOffer[_tokenId];//delete entry in mapping

        uint256[] storage _ids = addressToIds[msg.sender];
        for (uint256 index = 0; index < _ids.length; index++) {
            if (_ids[index] == _tokenId ) {
                _ids[index] = 0;
            }
        }
        
        emit MarketTransaction("Offer removed", msg.sender, _tokenId);
    }

    function buyLittleGui(uint256 _tokenId) public whenNotPaused{
        Offer memory _currentOffer = tokenIdToOffer[_tokenId];

        //checks
        require(_currentOffer.active, "There is no active offer for this little-gui");
    
        //effects
        delete tokenIdToOffer[_tokenId];//delete entry in mapping
        offers[_currentOffer.index].active = false;//don't iterate through array, but simply set active to false.
 
        uint256 _feeAmount = _currentOffer.price.mul(feePercent).div(100);    
        _payToken.safeTransferFrom(msg.sender, feeAddress, _feeAmount) ;
        _payToken.safeTransferFrom(msg.sender, _currentOffer.seller, _currentOffer.price - _feeAmount)  ;
        _littleGui.transferFrom(_currentOffer.seller, msg.sender, _tokenId);//ERC721 ownership transferred

        emit MarketTransaction("LittleGui successfully purchased", msg.sender, _tokenId);
    }
 
 
}