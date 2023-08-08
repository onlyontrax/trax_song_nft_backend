import Principal "mo:base/Principal";
import Array "mo:base/Array";
import Result     "mo:base/Result";
import Time "mo:base/Time";
import Text "mo:base/Text";
import Int "mo:base/Int";
import Iter "mo:base/Iter";
import Hash "mo:base/Hash";
import T "./types";
import Bool "mo:base/Bool";
import Debug "mo:base/Debug";
import Nat64 "mo:base/Nat64";
import Float "mo:base/Float";
import Blob "mo:base/Blob";
import List "mo:base/List";
import Error "mo:base/Error";
import Account "./utils/account";
import Buffer     "mo:base/Buffer";
import Hex        "./utils/Hex";
import Map  "mo:stable-hash-map/Map";

// Define the smart contract
actor TicketNFTMarketplace = {
  type Percentage = Float;
  type ArtistID = Principal;
  type FanID = Principal;
  type TransferArgs              = T.TransferArgs;
  type GetBlocksArgs             = T.GetBlocksArgs;
  type Result_1                  = T.Result_1;
  type BinaryAccountBalanceArgs        = T.BinaryAccountBalanceArgs;
  type QueryBlocksResponse       = T.QueryBlocksResponse;
  type Tokens                    = T.Tokens;
  type AccountIdentifier         = T.AccountIdentifier;

  let Ledger = actor "bd3sg-teaaa-aaaaa-qaaba-cai" : actor {
        query_blocks : shared query GetBlocksArgs -> async QueryBlocksResponse;
        transfer : shared TransferArgs -> async  Result_1;
        account_balance : shared query BinaryAccountBalanceArgs -> async Tokens;
    };

  let FEE : Nat64 = 10000;
  type Participants = {
    participantID: ArtistID;
    participantPercentage: Percentage;
  };

  type NFT = {
    id: Text;
    owner: Principal;
    productType: Text; // song, ticket
  };

  let { ihash; nhash; thash; phash; calcHash } = Map;

  // Define the NFT metadata struct
  type TicketMetaData = {
    id: Text;
    eventDate: Text;
    eventTime: Text;
    name: Text;
    location: Text;
    description: Text;
    totalSupply: Nat;
    price: Nat64;
    royalty: [Participants];
    ticker: Text;
    status: Text;
    schedule: Time.Time;
  };

  // Define the marketplace fee
  let marketplaceFee = 10;
  // Define the marketplace fee recipient
  let marketplaceFeeRecipient = Principal.fromText("c2v5t-vzv25-xvigb-jhc7d-whtnk-xhgrc-cesv5-lrnrp-grfrj-i6j3z-aae");
  stable var txNo : Nat64 = 0;

  stable let nfts = Map.new<Text, NFT>(thash);
  stable let ticketNfts = Map.new<Text, TicketMetaData>(thash);
  // Define fan's NFT Wallet
  stable let fanNFTWallet = Map.new<Principal, [Text]>(phash);
  // Define the artists and their NFTs
  stable let artistNFTs = Map.new<Principal, [Text]>(phash);
  private type FanToTime         = Map.Map<FanID, (Int, Nat, Text)>;
  private type ArtistToFan         = Map.Map<ArtistID, FanToTime>;
  stable let contentPaymentMap = Map.new<Text, ArtistToFan>(thash); 

  public query func getArtistTickets(artist: Principal) : async ?[Text] {
    return Map.get(artistNFTs, phash, artist);
  };

  public query func getFanTickets(fan: Principal) : async ?[Text] {
    return Map.get(fanNFTWallet, phash, fan);
  };
  
  public func candidAccountIdentifierToBlob(canisterId: Text) : async Blob {
    return Account.accountIdentifier(Principal.fromText(canisterId), Account.defaultSubaccount());
  };

  // Mint an NFT
  public shared({caller}) func mintTicketNFT(metadata: TicketMetaData) : async Text {
    // assert(await isStringEmpty(metadata.name)), "Name must be not empty");
    // assert(metadata.price > 0, "Price must be greater than 0");
    let now = Time.now();
    let nft : NFT = {
      id = Principal.toText(caller) # "-" # metadata.name # "-" # (Int.toText(now));
      owner = caller;
      productType = "ticket"
    };

    let ticket : TicketMetaData = {
      id = metadata.id;
      name = metadata.name;
      location = metadata.location;
      eventDate = metadata.eventDate;
      eventTime = metadata.eventTime;
      description = metadata.description;
      totalSupply = metadata.totalSupply;
      price = metadata.price;
      royalty = metadata.royalty;
      status = metadata.status;
      ticker = metadata.ticker;
      schedule = metadata.schedule;
    };

    var a = Map.put(nfts, thash, nft.id, nft);
    var b = Map.put(ticketNfts, thash, nft.id, ticket);
    switch (Map.get(artistNFTs, phash, caller)) {
      case (null) { var c = Map.put(artistNFTs, phash, caller, [nft.id]); };
      case (?nftArray) { var c = Map.put(artistNFTs, phash, caller, Array.append<Text>(nftArray, [nft.id])); };
    };
    nft.id;
  };

  // Buy an NFT
  public shared({ caller }) func purchaseTicket(id : Text): async () {
    let owner : Principal = caller;
    // assert(nfts.contains(id), "NFT does not exist");
    // assert(Array.find((x) => x == id, fanNFTWallet[owner]) == null, "Buyer already purchased the NFT");
    switch (await getTicketMetaData(id)) {
      case (null) { return; };
      case (?metadata) {
        // assert(metadata.status == "active", "NFT is not available for sale");
        let amountToSend = await platformDeduction(metadata.price - (FEE * 2)); 
        var count : Nat64 = 0;
        for (collabs in Iter.fromArray(metadata.royalty)) {
          let participantsCut : Nat64 = await getDeductedAmount(amountToSend - (FEE * count), collabs.participantPercentage);
          switch(await transfer(collabs.participantID, participantsCut)){
              case(#ok(res)){ 
                Debug.print("Paid artist: " # debug_show collabs.participantID #" amount: "# debug_show participantsCut #  " in block " # debug_show res);
                await addToContentPaymentMap(id, collabs.participantID, metadata.ticker, caller, Nat64.toNat(participantsCut));
              }; case(#err(msg)){   throw Error.reject("Unexpected error: " # debug_show msg);    };
            };
          count := count + 1;
        }
      };
    };
    switch (Map.get(fanNFTWallet, phash, owner)) {
      case (null) { var c = Map.put(fanNFTWallet, phash, caller, [id]); };
      case (?nftArray) { var c = Map.put(fanNFTWallet, phash, caller, Array.append<Text>(nftArray, [id])); };
    };
  };

  public query func getTicketMetaData(id : Text) : async ?TicketMetaData {
    // assert(nfts.contains(id), "NFT does not exist");
    // assert(getProductType(id) != "song", "Not song NFT");
    return Map.get(ticketNfts, thash, id);
  };

  private func platformDeduction(amount : Nat64) : async Nat64 {
    let fee = await getDeductedAmount(amount, 0.10);
    // Debug.print("deducted amount: " # debug_show fee);
    
    switch(await transfer(marketplaceFeeRecipient, fee)){
      case(#ok(res)){
        Debug.print("Fee of: " # debug_show fee # " paid to trax account: " # debug_show marketplaceFeeRecipient # " in block: " # debug_show res);
      };case(#err(msg)){
        throw Error.reject("Unexpected error: " # debug_show msg);
      }
    };

    let amountAfterDeduction = await getRemainingAfterDeduction(amount, 0.10);
    return amountAfterDeduction;
  };

  private func transfer(to: Principal, amount: Nat64): async Result.Result<Nat64, Text>{
    // Debug.print(Nat.fromText(Principal.toText(from)));
    // add ticker argument
    let now = Time.now();
    let res = await Ledger.transfer({
          memo = txNo; 
          from_subaccount = null;
          to = Blob.toArray(Account.accountIdentifier(to, Account.defaultSubaccount()));
          amount = { e8s = amount };
          fee = { e8s = FEE };
          created_at_time = ?{ timestamp_nanos = Nat64.fromNat(Int.abs(now)) };
        });

        Debug.print("res: "# debug_show res);
        
        switch (res) {
          case (#Ok(blockIndex)) {
            txNo += 1;
            Debug.print("Paid artist: " # debug_show to # " amount: " # debug_show amount # " in block: " # debug_show blockIndex);
            return #ok(blockIndex);
          };
          case (#Err(#InsufficientFunds { balance })) {

            return #err("Insufficient balance of " # debug_show balance # " from canister, trying to send: " # debug_show amount )
            
          };
          // case (#Err(#TxDuplicate {duplicate_of})) {
          //   await transfer(from, to, amount);
          // };
          case (#Err(other)) {
            return #err("Unexpected error: " # debug_show other);
          };
        };
  };

  private func getRemainingAfterDeduction(amount: Nat64, percent: Float) : async(Nat64){
    let priceFloat : Float = Float.fromInt(Nat64.toNat(amount));
    let deduction :  Float = priceFloat * percent;
    return Nat64.fromNat(Int.abs(Float.toInt(priceFloat - deduction)))
  };

  private func getDeductedAmount(amount: Nat64, percent: Float) : async(Nat64){
    let priceFloat : Float = Float.fromInt(Nat64.toNat(amount));
    return Nat64.fromNat(Int.abs(Float.toInt(priceFloat * percent)));
  };


  /**
    * args : { accountIdentifier : AccountIdentifier, canisterId  : ?Principal }
    * Takes an account identifier and returns a Blob
    *
    * Canister ID is required only for Principal, and will return an account identifier using that principal as a subaccount for the provided canisterId
    */
  public func accountIdentifierToBlob (args : T.AccountIdentifierToBlobArgs) : async T.AccountIdentifierToBlobResult {
    let accountIdentifier = args.accountIdentifier;
    let canisterId = args.canisterId;
    let err = {
      kind = #InvalidAccountIdentifier;
      message = ?"Invalid account identifier";
    };
    switch (accountIdentifier) {
      case(#text(identifier)){
        switch (Hex.decode(identifier)) {
          case(#ok v){
            let blob = Blob.fromArray(v);
            if(Account.validateAccountIdentifier(blob)){
              #ok(blob);
            } else {
              #err(err);
            }
          };
          case(#err _){
            #err(err);
          };
        };
      };
      case(#principal principal){
        switch(canisterId){
          case (null){
            #err({
              kind = #Other;
              message = ?"Canister Id is required for account identifiers of type principal";
            })
          };
          case (? id){
            let identifier = Account.accountIdentifier(id, Account.principalToSubaccount(principal));
            if(Account.validateAccountIdentifier(identifier)){
              #ok(identifier);
            } else {
              #err(err);
            }
          };
        }
      };
      case(#blob(identifier)){
        if(Account.validateAccountIdentifier(identifier)){
          #ok(identifier);
        } else {
          #err(err);
        }
      };
    };
  };
  /**
    * args : { accountIdentifier : AccountIdentifier, canisterId  : ?Principal }
    * Takes an account identifier and returns Hex-encoded Text
    *
    * Canister ID is required only for Principal, and will return an account identifier using that principal as a subaccount for the provided canisterId
    */
  public func accountIdentifierToText (args : T.AccountIdentifierToTextArgs) : async T.AccountIdentifierToTextResult {
    let accountIdentifier = args.accountIdentifier;
    let canisterId = args.canisterId;
    switch (accountIdentifier) {
      case(#text(identifier)){
        #ok(identifier);
      };
      case(#principal(identifier)){
        let blobResult = await accountIdentifierToBlob(args);
        switch(blobResult){
          case(#ok(blob)){
            #ok(Hex.encode(Blob.toArray(blob)));
          };
          case(#err(err)){
            #err(err);
          };
        };
      };
      case(#blob(identifier)){
        let blobResult = await accountIdentifierToBlob(args);
        switch(blobResult){
          case(#ok(blob)){
            #ok(Hex.encode(Blob.toArray(blob)));
          };
          case(#err(err)){
            #err(err);
          };
        };
      };
    };
  };

  public shared({caller}) func getCallerId() : async Principal {
    caller;
  };

  public shared({caller}) func getBalance(): async Tokens {
      var specifiedAccount = Account.accountIdentifier(caller, Account.defaultSubaccount());
      await Ledger.account_balance({ account = Blob.toArray(specifiedAccount) })
  };

  private func isStringEmpty(str: Text): async Bool {
    return Text.size(str) == 0;
  };

  private func addToContentPaymentMap(id: Text, artist: ArtistID, ticker: Text, fan: FanID, amount: Nat) : async(){
    let now = Time.now();
    switch(Map.get(contentPaymentMap, thash, id)){
      case(?innerMap){
        switch(Map.get(innerMap, phash, artist)){
          case(?hasInit){
              var a = Map.put(hasInit, phash, fan, (now, amount, ticker));
          };
          case null {
            var x : FanToTime = Map.new<FanID, (Int, Nat, Text)>(phash);
            
            var b = Map.put(x, phash, fan, (now, amount, ticker));
            
            var c = Map.put(innerMap, phash, artist, x);
          };
        };
        
      }; case null {
        var z : FanToTime = Map.new<FanID, (Int, Nat, Text)>(phash);
        var y : ArtistToFan = Map.new<ArtistID, FanToTime>(phash);
        var d = Map.put(z, phash, fan, (now, amount, ticker));
        var e = Map.put(y, phash, artist, z);
        var f = Map.put(contentPaymentMap, thash, id, y);
      }
    };
  };


  public func getAllContentPayments() : async [(Text, ArtistID, FanID, Int, Nat, Text)]{  

    var res = Buffer.Buffer<(Text, ArtistID, FanID, Int, Nat, Text)>(2);

    for((contentId, innerMap) in Map.entries(contentPaymentMap)){
      switch(await getTicketMetaData(contentId)){
        case(?content){
          for((artistId, fanId) in Map.entries(innerMap)){
            for((k,v) in Map.entries(fanId)){
              var fanId: FanID = k;
              var timestamp: Int = v.0;
              var amount: Nat = v.1;
              var ticker: Text = v.2;
              res.add(contentId, artistId, fanId, timestamp, amount, ticker);
            }
          }
        };
        case(null){

        }
      };

      
    };
    return Buffer.toArray(res);
  };

  public query func getAllArtistContentIDs(artist: ArtistID) : async [Text] {

    var ids = Buffer.Buffer<Text>(2);
    for((key, value) in Map.entries(nfts)){
      if(value.owner == artist){
        var id = key;
        ids.add(id);
      } else {
        switch (Map.get(ticketNfts, thash, key)) {
          case (?nft) {
            for(i in Iter.fromArray(nft.royalty)){
              if(artist == i.participantID){
                var partId = key;
                Debug.print("getAllArtistContentIDs id: " # debug_show partId);
                ids.add(partId);

              };
              Debug.print("getAllArtistContentIDs ids: " # debug_show Buffer.toArray(ids));
            };
          };
          case(null) {

          }
        }
        
      };
    };
    return Buffer.toArray(ids);
  };

  public func getAllArtistContentPayments(artist: ArtistID) : async [(Text, FanID, Int, Nat, Text)]{  
    let contentIds =  await getAllArtistContentIDs(artist);

    var res = Buffer.Buffer<(Text, FanID, Int, Nat, Text)>(2);

    for((key, value) in Map.entries(contentPaymentMap)){
      for(eachId in Iter.fromArray(contentIds)){
        if(key == eachId){
          for((a, b) in Map.entries(value)){
            if(a == artist){
              for((k,v) in Map.entries(b)){
                  var fanId: FanID = k;
                  var timestamp: Int = v.0;
                  var amount: Nat = v.1;
                  var ticker: Text = v.2;
                  res.add(eachId, fanId, timestamp, amount, ticker);
                }
            }
          }
        };
      };
    };
    return Buffer.toArray(res);
  };


  public func getAllFanContentPayments(fan: FanID) : async [(Text, Int, Nat, Text)]{ 
    
    var res = Buffer.Buffer<(Text, Int, Nat, Text)>(2);

    for((key, value) in Map.entries(contentPaymentMap)){ 
      for((a, b) in Map.entries(value)){
        for((k, v) in Map.entries(b)){
          if(k == fan){
            var contentId: Text = key;
            var timestamp: Int = v.0;
            var amount: Nat = v.1;
            var ticker: Text = v.2;
            res.add(contentId, timestamp, amount, ticker);
          }
        };
      }; 
    };
    return Buffer.toArray(res);
  };

  public func getAllTicketNFTs() : async [(Text, Text, Text, Text, Text, Text, Nat, Nat64, Text)] {
    var res = Buffer.Buffer<(Text, Text, Text, Text, Text, Text, Nat, Nat64, Text)>(2);
    for ((key, value) in Map.entries(nfts)) {
      switch(await getTicketMetaData(key)) {
        case(?ticket) {
          res.add(key, ticket.name, ticket.location, ticket.eventDate, ticket.eventTime, ticket.description, ticket.totalSupply, ticket.price, ticket.ticker);
        };
        case (null) {

        };
      };
    };
    return Buffer.toArray(res);
  };
}
