// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title FairTicket
/// @notice Anti-scalping event ticketing:
///         - per-wallet mint cap  -> fairness at the primary sale (no bulk-buying bots)
///         - enforced resale price cap -> fairness on resale, enforced by the contract itself
///         - on-chain check-in -> only the real current owner's wallet can check a ticket in
contract FairTicket is ERC721, Ownable {
    struct EventInfo {
        string name;
        uint256 facePrice;     // price in wei to mint one ticket
        uint256 maxResaleBps;  // resale cap as basis points of facePrice, e.g. 11000 = 110%
        uint256 maxSupply;
        uint256 minted;
        uint256 maxPerWallet;  // primary-sale fairness: max tickets one wallet may mint
        bool exists;
    }

    struct Listing {
        uint256 price;
        bool active;
    }

    uint256 public nextEventId;
    uint256 public nextTokenId;

    mapping(uint256 => EventInfo) public events;
    mapping(uint256 => uint256) public ticketEvent;                       // tokenId  => eventId
    mapping(uint256 => mapping(address => uint256)) public mintedPerWallet; // eventId => wallet => count
    mapping(uint256 => Listing) public listings;                          // tokenId  => resale listing
    mapping(uint256 => bool) public checkedIn;                            // tokenId  => used at gate

    event EventCreated(uint256 indexed eventId, string name, uint256 facePrice, uint256 maxSupply, uint256 maxPerWallet);
    event TicketMinted(uint256 indexed eventId, uint256 indexed tokenId, address indexed buyer);
    event TicketListed(uint256 indexed tokenId, uint256 price);
    event ListingCancelled(uint256 indexed tokenId);
    event TicketResold(uint256 indexed tokenId, address indexed from, address indexed to, uint256 price);
    event TicketCheckedIn(uint256 indexed tokenId, address indexed attendee);

    constructor() ERC721("FairTicket", "FTIX") Ownable(msg.sender) {}

    // ---------- Organizer ----------

    function createEvent(
        string calldata name,
        uint256 facePrice,
        uint256 maxResaleBps,
        uint256 maxSupply,
        uint256 maxPerWallet
    ) external onlyOwner returns (uint256 eventId) {
        require(maxResaleBps >= 10000, "cap must be >= 100% of face price");
        eventId = nextEventId++;
        events[eventId] = EventInfo(name, facePrice, maxResaleBps, maxSupply, 0, maxPerWallet, true);
        emit EventCreated(eventId, name, facePrice, maxSupply, maxPerWallet);
    }

    // ---------- Primary sale ----------

    function mint(uint256 eventId) external payable returns (uint256 tokenId) {
        EventInfo storage e = events[eventId];
        require(e.exists, "event does not exist");
        require(e.minted < e.maxSupply, "sold out");
        require(mintedPerWallet[eventId][msg.sender] < e.maxPerWallet, "wallet mint limit reached");
        require(msg.value == e.facePrice, "send exact face price");

        tokenId = nextTokenId++;
        ticketEvent[tokenId] = eventId;
        e.minted += 1;
        mintedPerWallet[eventId][msg.sender] += 1;

        _safeMint(msg.sender, tokenId);
        emit TicketMinted(eventId, tokenId, msg.sender);
    }

    // ---------- Resale, price-capped and contract-escrowed ----------

    function listForResale(uint256 tokenId, uint256 price) external {
        require(ownerOf(tokenId) == msg.sender, "not your ticket");
        require(!checkedIn[tokenId], "already used, cannot resell");
        require(price <= resaleCap(tokenId), "price exceeds resale cap");

        listings[tokenId] = Listing(price, true);
        emit TicketListed(tokenId, price);
    }

    function cancelListing(uint256 tokenId) external {
        require(ownerOf(tokenId) == msg.sender, "not your ticket");
        delete listings[tokenId];
        emit ListingCancelled(tokenId);
    }

    function buyResale(uint256 tokenId) external payable {
        Listing memory l = listings[tokenId];
        require(l.active, "not listed for resale");
        require(msg.value == l.price, "send exact listed price");
        require(!checkedIn[tokenId], "already used");

        address seller = ownerOf(tokenId);
        delete listings[tokenId];

        _transfer(seller, msg.sender, tokenId);

        (bool sent, ) = payable(seller).call{value: msg.value}("");
        require(sent, "payment to seller failed");

        emit TicketResold(tokenId, seller, msg.sender, l.price);
    }

    /// @notice The maximum price this specific ticket may ever be listed for.
    function resaleCap(uint256 tokenId) public view returns (uint256) {
        EventInfo storage e = events[ticketEvent[tokenId]];
        return (e.facePrice * e.maxResaleBps) / 10000;
    }

    // ---------- Close the resale-cap loophole ----------

    /// @dev Standard ERC-721 transfers are disabled on purpose. Without this,
    /// anyone could skip buyResale() and call transferFrom() directly after
    /// agreeing a price off-chain (e.g. cash), completely bypassing the resale
    /// cap. The ONLY way a ticket can change hands after minting is buyResale(),
    /// which enforces the price cap. Minting and internal resale transfers are
    /// unaffected since they use the internal _safeMint/_transfer, not these.
    function transferFrom(address, address, uint256) public pure override {
        revert("Use buyResale() - direct transfers are disabled to enforce the price cap");
    }

    function safeTransferFrom(address, address, uint256, bytes memory) public pure override {
        revert("Use buyResale() - direct transfers are disabled to enforce the price cap");
    }

    // ---------- Gate check-in ----------

    /// @notice Must be called by the wallet that currently owns the ticket.
    /// Sending this transaction IS the proof of ownership - a forwarded
    /// screenshot of a QR code cannot sign or send this, only the real
    /// private key holder can. That's what stops informal resale.
    function checkIn(uint256 tokenId) external {
        require(ownerOf(tokenId) == msg.sender, "not your ticket");
        require(!checkedIn[tokenId], "already checked in");
        checkedIn[tokenId] = true;
        emit TicketCheckedIn(tokenId, msg.sender);
    }
}
