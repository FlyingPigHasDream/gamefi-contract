/**
 * @func  setSaleRATE 
 * 设置交易手续费
 * @param { uint256 } 
 * @return { } 
 *
 * @func  setBaseUrl 
 * 设置NFT图片线上链接地址
 * @param { string } 
 * @return { }
 *
 * @func  setBaseUrl 
 * 设置NFT图片线上链接地址
 * @param { string } 
 * @return { } 
 *
 * @func  setAvalibleForSale 
 * 设置NFT可卖及价格
 * @param { uint256 nftID,uint256 price } 
 * @return { } 
 *
 * @func  setDisableForSale 
 * 设置NFT不可卖
 * @param { uint256 nftID } 
 * @return { } 
 *
 * @func  setMintInfo 
 * 设置每批次NFT的发行信息，数量及每个稀有度的价格
 * @param { uint256 _currentMintCount,uint256 _level1Price,uint256 _level2Price,uint256 _level3Price,uint256 _level4Price,uint256 _level5Price } 
 * @return { } 
 *
 * @func  setMintTokenAddress 
 * 设置买卖NFT所用代币的地址
 * @param { address tokenAddress } 
 * @return { } 
 *
 * @func  setFeeAddress 
 * 设置NFT交易手续费接收地址
 * @param { address feeaddress } 
 * @return { } 
 *
 * @func  setNFTFeeAddress 
 * 设置NFT初始化时的收费地址
 * @param { address mintFeeAddress } 
 * @return { } 
 *
 * @func  mintNFT 
 * 初始化一个NFT
 * @param { } 
 * @return { } 
 *
 * @func  getNFTInfoByID 
 * 通过ID 查取NFT详细信息
 * @param { uint256 nftID } 
 * @return { } 
 *
 * @func  balanceOf 
 * 查询某个账户的NFT总数
 * @param { address userAddress } 
 * @return { uint256 } 
 *
 * @func  safeTransfer 
 * 购买某个NFT
 * @param { uint256 nftID } 
 * @return { } 
 *
 * @func  tokenOfOwnerByIndex 
 * 通过账户地址查询该账户第 index 个NFT的ID，用于 筛选 某个账户的全部NFT
 * @param { address userAddress,uint256 index } 
 * @return { uint256 } 
 *
 * @func  balanceOf 
 * 查询某个账户的NFT总数
 * @param { address userAddress } 
 * @return { uint256 } 
 */ 



pragma solidity ^0.7.3;

import "./IERC721.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import {SafeMath} from "@openzeppelin/contracts/math/SafeMath.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/EnumerableSet.sol";

library Strings {
    function toString(uint256 value) internal pure returns (string memory) {
        // Inspired by OraclizeAPI's implementation - MIT licence
        // https://github.com/oraclize/ethereum-api/blob/b42146b063c7d6ee1358846c198246239e9360e8/oraclizeAPI_0.4.25.sol
    
        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        uint256 index = digits - 1;
        temp = value;
        while (temp != 0) {
            buffer[index--] = bytes1(uint8(48 + temp % 10));
            temp /= 10;
        }
        return string(buffer);
    }
}
 
interface IERC721Receiver {
    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data) external returns (bytes4);
}
 
interface IPriceOracle {
    function okflyOktPrice( ) external view returns (uint256);
    function okflyUsdtPrice( ) external view returns (uint256);
    function usdtToOkfly(uint256 _usdtAmount)  external view returns (uint256 okflyAmount);     
}

contract LittleGui is IERC721 {

    event MarketTransaction(string TxType, address owner, uint256 tokenId);

    using Strings for uint256;
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.UintSet;
  
    // tokenURI baseUrl
    string private baseUrl = "http://d-d.design/NFT";
    
    //tokenInfo
    string private constant nameOfToken = 'Little Gui';
    string private constant symbolOfToken = 'LG';
 
    
    uint8 public decimals;
    uint8 private tokenDemicals;
    uint256 public SALE_RATE;  //交易手续费
    uint256 private currentMintTotal; //当前发行批次
    uint256 private level1Price; //level1发行的价格
    uint256 private level2Price; //level2发行的价格
    uint256 private level3Price; //level3发行的价格
    uint256 private level4Price; //level4发行的价格
    uint256 private level5Price; //level5发行的价格
    uint256 private mintTotal; //总发行量
    uint256 private hasBuyCount; //NFT 挖出总量
    uint256 public mintNFTFee; //抽取NFT的花费 USDT
    uint256 public skinPrice;  //皮肤的价格==挖矿加成的价格
  
    address owner;
    
    address buyFeeAddress; //收取交易手续费的地址
    address mintFeeAddress; //初始买NFT费用的地址
    EnumerableSet.UintSet sales;
    
    IERC20 public payToken;
    IPriceOracle public priceOracle;

    uint256[] public levels1;
    uint256[] public levels2;
    uint256[] public levels3;
    uint256[] public levels4;
    uint256[] public levels5;

    modifier onlyAllowed() {
        require(msg.sender == owner,"Not Authorised");
        _;
    }
    
    constructor(address _payToken, address _priceOracle) {
        payToken = IERC20(_payToken);
        priceOracle = IPriceOracle(_priceOracle);
        decimals = 0;
        tokenDemicals = 18;
        SALE_RATE = 3;  //3%  交易抽点
        currentMintTotal = 0;
        mintTotal = 0;
        hasBuyCount = 0;
        mintNFTFee = 5000000000000000000; //抽取NFT的费用 5U
        skinPrice = 50000000000;  //50okfly
        owner = msg.sender;
  
        buyFeeAddress = 0x5C04ceDC0968ADfFF6C810fbB12b401E5A1c7EbB;
        mintFeeAddress = 0x5C04ceDC0968ADfFF6C810fbB12b401E5A1c7EbB;
    }
    
    function name() override external pure returns (string memory tokenName) {
        return nameOfToken;
    }

    function symbol() override external pure returns (string memory tokenSymbol) {
        return symbolOfToken;
    }

    function totalSupply() override external view returns (uint256 total) {
        return mintTotal;
    }
 

    //token
    struct NFTData {
        uint256 _nftID;   //nft 唯一标识 从 1 开始
        address _preOwner; //上次的owner
        address _nowOwner; //当前owner
        string _tokenURI;  //NFT图片地址
        uint256 _isForSale;   //1 sale  0 unsale
        uint256 _mintPriceForSale;  //mint  price
        uint256 _targetPriceForSale; //sale price
        uint256 _nftLevel;  //稀有度 1，2，3，4，5
        uint256 skin;   
        bool isInitialed;  //是否初始化
        bool isBuy;  //是否已被购买
    }
    //address NFT balance
    mapping (address => uint256) private balances;
    mapping (uint256 => NFTData) private NFTLISTS;
    mapping (uint256 => address) private owners;
    
    mapping (uint256 => address) private _tokenApprovals;
    mapping (address => mapping (address => bool)) private _operatorApprovals;
    
    mapping(address => mapping(uint256 => uint256)) private ownerTokens;
    //记录账号最近一次抽取过得NFT
    mapping(address => uint256) private latestGotNFT;
  
    //events
    event mintSuccess(address indexed to, uint256 _nftID,bool isMintSuccess);
    event buySuccess(address indexed to, uint256 _nftID);
    event UpdateSkin(address indexed to, uint256 _nftID,uint256 skin);
    event BuySkin(address indexed to, uint256 _nftID);
  

    //set rate 
    function setSaleRATE(uint256 _rate) external onlyAllowed {
        require(_rate >= 0 && _rate <= 100,'invalid rate');
        SALE_RATE = _rate;
    }
    function setMintNFTFee(uint256 _mintNFTFee) external onlyAllowed {
        require(_mintNFTFee >= 0,'invalid mintNFTFee');
        mintNFTFee = _mintNFTFee;
    }
    //baseUrl 
    function setBaseUrl(string memory _baseUrl) external onlyAllowed {
        baseUrl = _baseUrl;
    }
    //token sale info
    function setAvalibleForSale(uint256 _nftID,uint256 _price) public {
        require(NFTLISTS[_nftID].isInitialed,'target NFT is not mint');
        require(msg.sender == NFTLISTS[_nftID]._nowOwner,'its not belong to you,no access to change price');
        require(_price > 0,'sale price need to more than zero.');
        NFTLISTS[_nftID]._isForSale = 1;
        NFTLISTS[_nftID]._targetPriceForSale = _price;
        sales.add(_nftID);
    }
    function setDisableForSale(uint256 _nftID) public {
        require(NFTLISTS[_nftID].isInitialed,'target NFT is not mint');
        require(msg.sender == NFTLISTS[_nftID]._nowOwner,'its not belong to you,no access to disable');
        NFTLISTS[_nftID]._isForSale = 0;
        sales.remove(_nftID);
    }
    function getLatestNFTIDByAddress(address _address) public view returns(uint256) {
        return latestGotNFT[_address];
    }

    function buyLittleGui(uint256 _tokenId) public{
        NFTData storage nftData = NFTLISTS[_tokenId];
        require(nftData._isForSale == 1,'target NFT is not for sale');
        require(nftData._nowOwner != msg.sender,'Cannot transfer target NFT to yourself!');
        uint256 _feeAmount = nftData._targetPriceForSale.mul(SALE_RATE).div(100);    
        payToken.safeTransferFrom(msg.sender, buyFeeAddress, _feeAmount) ;
        payToken.safeTransferFrom(msg.sender, nftData._nowOwner, nftData._targetPriceForSale - _feeAmount)  ;
        
        _transfer(nftData._nowOwner, msg.sender, _tokenId);
        nftData._isForSale = 0;
        sales.remove(_tokenId);

        emit MarketTransaction("LittleGui successfully purchased", msg.sender, _tokenId);
    }

    function setMintInfo(uint256 _currentMintCount,uint256 _level1Price,uint256 _level2Price,uint256 _level3Price,uint256 _level4Price,uint256 _level5Price) public onlyAllowed {
        require(_currentMintCount > 0,'mint NFT number should more than zero');
        require(_level1Price > 0 && _level2Price > 0 && _level3Price > 0 && _level4Price > 0 && _level5Price > 0,'mint NFT price should more than zero');
        mintTotal = currentMintTotal.add(_currentMintCount);
        level1Price = _level1Price;
        level2Price = _level2Price;
        level3Price = _level3Price;
        level4Price = _level4Price;
        level5Price = _level5Price;
    }
   
    function setFeeAddress(address _feeAddress) public onlyAllowed {
        require(!isContract(_feeAddress),'address is invalid');
        buyFeeAddress = _feeAddress;
    }
    function setNFTFeeAddress(address _nftFeeAddress) public onlyAllowed {
        require(!isContract(_nftFeeAddress),'address is invalid');
        mintFeeAddress = _nftFeeAddress;
    }
    function setSkinPrice(uint256 _skinPrice) public onlyAllowed {
        require(_skinPrice > 0,'skin price should more than zero');
        skinPrice = _skinPrice;
    }
    function getNFTHasBuyTotal() public view returns(uint256) {
      return hasBuyCount;
    }


    
    //exactly mint logic  get Nft info by index
    function mintNFT() public {
        //抽到没有被购买的，算是抽中返回ID，抽中已经被购买的算是未抽中，返回0
        require(mintTotal > 0,'please set mint total first!');
        address to = msg.sender;
        payToken.safeTransferFrom(to, mintFeeAddress, priceOracle.usdtToOkfly(mintNFTFee));
        uint256 index = getRandom(mintTotal);
        string memory nftKey = formatKey(index);
        uint8 level = getUniqueLevel(nftKey);
        uint256 currentMintPrice = 0;
        if(level == 1) {
            currentMintPrice = level1Price;
        }else if(level == 2) {
            currentMintPrice = level2Price;
        }else if(level == 3) {
            currentMintPrice = level3Price;
        }else if(level == 4) {
            currentMintPrice = level4Price;
        }else if(level == 5) {
            currentMintPrice = level5Price;
        }
        NFTData storage nftData = NFTLISTS[index+1];
        if(nftData.isBuy) {
          emit mintSuccess(to,index+1,false);
        }else {
          latestGotNFT[to]  = index+1;
          NFTLISTS[index+1] = NFTData({
            _nftID: index+1, 
            _preOwner: to, 
            _nowOwner: to,
            _tokenURI: string(abi.encodePacked(baseUrl,'/?NFTCode=', formatKey(index), '&skin=0')),
            _isForSale: 0,
            _mintPriceForSale: currentMintPrice,
            _targetPriceForSale: currentMintPrice,
            _nftLevel: level,
            skin: 0,
            isInitialed: true,
            isBuy: false
          });
          saveTokenLevel(level, index+1);
          emit mintSuccess(to,index+1,true);
        }
    }

    function saveTokenLevel(uint256 level, uint256 tokenId) internal {
        if(level == 1) {
            levels1.push(tokenId);
        }else if(level == 2) {
            levels2.push(tokenId);
        }else if(level == 3) {
            levels3.push(tokenId);
        }else if(level == 4) {
            levels4.push(tokenId);
        }else if(level == 5) {
            levels5.push(tokenId);
        }        
    }    

    function firstBuyNFT() public {
      address buyAddress = msg.sender;
      uint256 buyNFTID = latestGotNFT[buyAddress];
      require(buyNFTID > 0,'you did not mint nft,please mint first!');
      NFTData storage nftData = NFTLISTS[buyNFTID];
      require(!nftData.isBuy,'target nft is bought by others,please remint!');
      payToken.safeTransferFrom(buyAddress, mintFeeAddress, nftData._mintPriceForSale);
      nftData._preOwner = buyAddress;
      nftData._nowOwner = buyAddress;
      nftData.isBuy = true;
      ownerTokens[buyAddress][balances[buyAddress]] = nftData._nftID;
      balances[buyAddress] += 1;
      owners[nftData._nftID] = buyAddress;
      hasBuyCount++;
      latestGotNFT[buyAddress] = 0;
      emit buySuccess(buyAddress,buyNFTID);
    }

    function buySkin(uint256 _nftID) public {
      NFTData storage nftData = NFTLISTS[_nftID];
      require(nftData.isInitialed && nftData.isBuy,'target NFT is not mint!');
      require(nftData._nowOwner == msg.sender,'target NFT is not belong to you!');
      require(nftData.skin == 0,'target NFT has bought skin!');
      payToken.safeTransferFrom(msg.sender, mintFeeAddress, skinPrice);
      nftData.skin = 1;
      nftData._mintPriceForSale = nftData._mintPriceForSale.add(skinPrice);
      nftData._tokenURI = string(abi.encodePacked(baseUrl,'/?NFTCode=', formatKey(_nftID.sub(1)), '&skin=1'));
      emit BuySkin(msg.sender,_nftID);
    }
    
    function getNFTInfoByID(uint256 _nftID) public override view returns(uint256,address,address,uint256,string memory,uint256,uint256,uint256,uint256,bool,bool)  {
        NFTData storage nftData = NFTLISTS[_nftID];
        return (
            nftData._nftID,
            nftData._preOwner,
            nftData._nowOwner,
            nftData._nftLevel,
            nftData._tokenURI,
            nftData._isForSale,
            nftData._mintPriceForSale,
            nftData._targetPriceForSale,
            nftData.skin,
            nftData.isInitialed,
            nftData.isBuy
        );
    }
    
    function setSkin(uint256 _tokenId,uint256 _skin) public {
        NFTData storage nftData = NFTLISTS[_tokenId];
        nftData.skin = _skin;

        emit UpdateSkin(msg.sender, _tokenId, _skin);
    }
    
    function balanceOf(address _address) override public view returns(uint256) {
        return balances[_address];
    }
    
/*     function safeTransfer(uint256 _nftID) public  {
        require(NFTLISTS[_nftID].isInitialed,"target NFT is not mint,please mint first.");
        require(NFTLISTS[_nftID]._isForSale == 1,"target NFT is not for sale.");
        //mintTokenContract LGToken = mintTokenContract(payToken);
        //require(LGToken.balanceOf(msg.sender) >= NFTLISTS[_nftID]._targetPriceForSale,"you dont have enough money to buy.");
        address currentOwner = owners[_nftID];
        require(currentOwner != msg.sender,"cant transfer NFT to youself.");
        //uint256 rateMoney = NFTLISTS[_nftID]._targetPriceForSale.mul(SALE_RATE).div(100);
        //uint256 nftSaleMoney = NFTLISTS[_nftID]._targetPriceForSale.sub(NFTLISTS[_nftID]._targetPriceForSale.mul(SALE_RATE).div(100));
        //LGToken.transferFrom(msg.sender,currentOwner,nftSaleMoney);
        //LGToken.transferFrom(msg.sender,buyFeeAddress,rateMoney);
        safeTransferFrom(currentOwner, msg.sender, _nftID, "");
    } */

    function transfer(address _to, uint256 _tokenId) override external {
        require(_to != address(0), "Cannot transfer to 0 address");
        require(_to != address(this), "Cannot transfer to contract address");
        require(ownerOf(_tokenId) == msg.sender  , "Token must be owned by sender");

        _transfer(msg.sender, _to, _tokenId);
    }

    function transferFrom(address from, address to, uint256 tokenId) override public  {
        require(_transferFromRequire(msg.sender, from, to, tokenId));

        _transfer(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) override external  {
        safeTransferFrom(from, to, tokenId, "");
    }
    
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory _data) override public  {
        require(_transferFromRequire(msg.sender, from, to, tokenId));
        _safeTransfer(from, to, tokenId, _data);
    }
    
    function _safeTransfer(address from, address to, uint256 tokenId, bytes memory _data) internal  {
        _transfer(from, to, tokenId);
        require(_checkOnERC721Received(from, to, tokenId, _data), "ERC721: transfer to non ERC721Receiver implementer");
    }
    
    function _transfer(address from, address to, uint256 tokenId) internal  {
        require(tokenId > 0,'NFT ID is more than zero!');
        require(_exists(tokenId),"NFT is not exists");
        _beforeTokenTransfer(from, to, tokenId);

        // Clear approvals from the previous owner
        _approve(address(0), tokenId);
        removeFromTokenList(from,tokenId);
        balances[from] -= 1;
        ownerTokens[to][balances[to]] = tokenId;
        balances[to] += 1;
        owners[tokenId] = to;
        NFTLISTS[tokenId]._preOwner = from;
        NFTLISTS[tokenId]._nowOwner = to;
        // reset sale state
        NFTLISTS[tokenId]._isForSale = 0;
        sales.remove(tokenId);
        
        emit Transfer(from, to, tokenId);
    }

    function _transferFromRequire(address _spender, address _from, address _to, uint256 _tokenId) private view returns (bool) {
        require(_to != address(0), "Cannot transfer to 0 address"); 
        require(ownerOf(_tokenId) == _from, "Token must be owned by the address from");

        return _isApprovedOrOwner(_spender, _tokenId)  ;
    }
    
    function approve(address to, uint256 tokenId) override public   {
        address _owner = ownerOf(tokenId);
        require(to != _owner, "ERC721: approval to current owner");

        require(
            msg.sender == _owner || isApprovedForAll(_owner, msg.sender),
            "ERC721: approve caller is not owner nor approved for all"
        );

        _approve(to, tokenId);
    }
    
    function _approve(address to, uint256 tokenId) internal  {
        _tokenApprovals[tokenId] = to;
        emit Approval(ownerOf(tokenId), to, tokenId);
    }
    
    
    function setApprovalForAll(address operator, bool approved) override public  {
        require(operator != msg.sender, "approve to caller");

        _operatorApprovals[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }
  
    
    //tool funcs 
    uint256[] private tokenIDArr;
    function removeFromTokenList(address _owner, uint256 _tokenId) private {
        delete tokenIDArr;
        for(uint256 i = 0;i < balances[_owner];i++){
          if(ownerTokens[_owner][i] != _tokenId) {
              tokenIDArr.push(ownerTokens[_owner][i]);
          }else {
              ownerTokens[_owner][i] = 0;
          }
        }
        for(uint256 i = 0;i < balances[_owner];i++) {
            if(i < tokenIDArr.length) {
                ownerTokens[_owner][i] = tokenIDArr[i];
            }else {
                ownerTokens[_owner][i] = 0;
            }
        }
    }
    
    function getAllTokensOnSale() public view returns (uint256[] memory listOfOffers) {
        uint256 _len = sales.length();
        uint256[] memory _tokens = new uint256[](_len);

        for (uint256 index = 0; index < _len; index++) {
            _tokens[index] = sales.at(index);
        }

        return _tokens;
    }

    function getTokensOnSale(address _owner) public view returns (uint256[] memory listOfOffers) {
        uint256 _len = 0;

        for(uint256 i = 0;i < balances[_owner];i++){
          if (NFTLISTS[ownerTokens[_owner][i]]._isForSale == 1) {
             _len++;
          }
        }
     
        if (_len == 0) {
            return new uint256[](0);//returns empty array
        } else {
            uint256 _id;
            uint256[] memory _tokens = new uint256[](_len);
            _len = 0;//reset index of new array
            for(uint256 i = 0; i < balances[_owner]; i++){
                _id = ownerTokens[_owner][i];
                if (NFTLISTS[_id]._isForSale == 1) {
                    _tokens[_len] = _id;
                    _len++;
                }
            }
            return _tokens;
        }   
    }

    function getTokensByAddress(address _owner) public view returns (uint256[] memory listOfOffers) {
        uint256[] memory _tokens = new uint256[](balances[_owner]);
    
        for(uint256 i = 0; i < balances[_owner]; i++){
            _tokens[i] = ownerTokens[_owner][i];
        }
        return _tokens;
    }

    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view  returns (bool) {
        require(_exists(tokenId), "NFT is not exists");
        address _owner = ownerOf(tokenId);
        return (spender == _owner || getApproved(tokenId) == spender || isApprovedForAll(_owner, spender));
    }
    function _exists(uint256 tokenId) internal view  returns (bool) {
        return owners[tokenId] != address(0);
    }
    function ownerOf(uint256 tokenId) override public view  returns (address) {
        address _owner = owners[tokenId];
        require(_owner != address(0), "NFT is not belong to yourself or not exists");
        return _owner;
    }
    function getApproved(uint256 tokenId) override public view  returns (address) {
        require(_exists(tokenId), "NFT is not exists");

        return _tokenApprovals[tokenId];
    }
    function isApprovedForAll(address _owner, address operator) override public view  returns (bool) {
        return _operatorApprovals[_owner][operator];
    }
    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal  { }
    
    function _checkOnERC721Received(address from, address to, uint256 tokenId, bytes memory _data) private returns (bool) {
        if (isContract(to)) {
            try IERC721Receiver(to).onERC721Received(msg.sender, from, tokenId, _data) returns (bytes4 retval) {
                return retval == IERC721Receiver(to).onERC721Received.selector;
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert("ERC721: transfer to non ERC721Receiver implementer");
                } else {
                    // solhint-disable-next-line no-inline-assembly
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        } else {
            return true;
        }
    }
    
    function tokenByIndex(uint256 _index) external view returns (uint256) {}
    
    function tokenOfOwnerByIndex(address _owner, uint256 _index) external view returns (uint256) {
        return ownerTokens[_owner][_index];
    }
    
    function isContract(address account) internal view returns (bool) {
        uint256 size;
        // solhint-disable-next-line no-inline-assembly
        assembly { size := extcodesize(account) }
        return size > 0;
    }
    
    function getRandom(uint256 _length) private view returns(uint256) {
        uint256 random = uint256(keccak256(abi.encodePacked(block.difficulty, block.timestamp)));
        return random.mod(_length);
    }
    
    function formatKey(uint256 _index) private pure returns(string memory) {
        if(_index < 10) {
            return string(abi.encodePacked('000', uint256(_index).toString()));
        }else if(_index >= 10 && _index < 100 ) {
            return string(abi.encodePacked('00', uint256(_index).toString()));
        }else if(_index >= 100 && _index < 1000) {
            return string(abi.encodePacked('0', uint256(_index).toString()));
        }else {
            return string(abi.encodePacked('', uint256(_index).toString()));
        }
    }
    
    function getUniqueLevel(string memory _str) private pure returns(uint8) {
        uint8 level = 5;
        bytes memory str = bytes(_str);
        string memory tmp = new string(str.length);
        bytes memory key = bytes(tmp);
        for(uint8 i = 0;i < 4;i++) {
            key[3 - i] = str[str.length - i - 1];
        }
        uint8 index1 = 0;
        uint8 index2 = 0;
        uint8 index3 = 0;
        uint8 index4 = 0;
        for(uint8 i = 0;i < 4;i++) {
            bytes1 keyB1 = key[i];
            for(uint8 j = 0;j < 4;j++) {
                if(keyB1 == key[j]) {
                    if(i == 0) {
                        index1++;
                    }else if(i == 1) {
                        index2++;
                    }else if(i == 2) {
                        index3++;
                    }else if(i == 3) {
                        index4++;
                    }
                }
            }
        }
        //一对数字一样 
        if(index1 == 2 || index2 == 2 || index3 == 2 || index4 == 2) {
            level = 4;
        }
        //三个数字一样
        if(index1 == 3 || index2 == 3 || index3 == 3 || index4 == 3) {
            level = 3;
        }
        //两对数字一样
        if(index1 == 2 && index2 == 2 && index3 == 2 && index4 == 2) {
            level = 2;
        }
        //全部一样
        if(index1 == 4) {
            level = 1;
        }
        return level;
    }   
}