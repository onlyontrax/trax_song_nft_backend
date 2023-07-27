import Principal "mo:base/Principal";
import Array "mo:base/Array";
import Result     "mo:base/Result";
import HashMap "mo:base/HashMap";
// import Map  "mo:stable-hash-map/Map";
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
import Hex        "./utils/Hex";

// Define the smart contract
actor NFTMarketplace = {
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

  let Ledger = actor "bkyz2-fmaaa-aaaaa-qaaaq-cai" : actor {
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

  // Define the NFT metadata struct
  type SongMetaData = {
    id: Text;
    name: Text;
    description: Text;
    totalSupply: Nat;
    price: Nat64;
    loyalty: [Participants];
    status: Text;
    schedule: Time.Time;
  };

  type TicketMetaData = {
    time: Time.Time;
    name: Text;
    location: Text;
    description: Text;
    totalSupply: Nat;
    price: Nat64;
    loyalty: [Participants];
    status: Text;
    schedule: Time.Time;
  };

  // Define the transaction struct
  type Transaction = {
    id: Text;
    productType: Text;
    nftId: Text;
    buyer: Principal;
    amount: Nat;
  };

  // Define the marketplace fee recipient
  let marketplaceFeeRecipient = Principal.fromText("c2v5t-vzv25-xvigb-jhc7d-whtnk-xhgrc-cesv5-lrnrp-grfrj-i6j3z-aae");

  var nfts : HashMap.HashMap<Text, NFT> = HashMap.HashMap<Text, NFT>(1, Text.equal, Text.hash);
  stable var txNo : Nat64 = 0;
  // var nftList : [Text] = [];
  var songNfts : HashMap.HashMap<Text, SongMetaData> = HashMap.HashMap<Text, SongMetaData>(1, Text.equal, Text.hash);
  var ticketNfts: HashMap.HashMap<Text, TicketMetaData> = HashMap.HashMap<Text, TicketMetaData>(1, Text.equal, Text.hash);

  // Define fan's NFT Wallet
  var fanNFTWallet : HashMap.HashMap<Principal, [Text]> = HashMap.HashMap<Principal, [Text]>(1, Principal.equal, Principal.hash);

  // Define the artists and their NFTs
  var artistNFTs : HashMap.HashMap<Principal, [Text]> = HashMap.HashMap<Principal, [Text]>(1, Principal.equal, Principal.hash);

  // Define the transactions
  var transactions : HashMap.HashMap<Text, Transaction> = HashMap.HashMap<Text, Transaction>(1, Text.equal, Text.hash);

  // Define the marketplace fee
  let marketplaceFee = 10;

  public shared({caller}) func getArticleSongs() : async ?[Text] {
    return artistNFTs.get(caller);
  };

  public shared({caller}) func getFanSongs() : async ?[Text] {
    return fanNFTWallet.get(caller);
  };

  // Mint an NFT
  public shared({caller}) func mintSongNFT(metadata: SongMetaData) : async Text {
    // assert(Text.size("metadata.name") == 0, "Name must be not empty");
    // assert(metadata.price > 0, "Price must be greater than 0");
    let now = Time.now();
    let nft : NFT = {
      id = Principal.toText(caller) # "-" # metadata.name # "-" # (Int.toText(now));
      owner = caller;
      productType = "song"
    };

    let song : SongMetaData = {
      id = metadata.id;
      name = metadata.name;
      description = metadata.description;
      totalSupply = metadata.totalSupply;
      price = metadata.price;
      loyalty = metadata.loyalty;
      status = metadata.status;
      schedule = metadata.schedule;
    };

    nfts.put(nft.id, nft);
    songNfts.put(nft.id, song);
    switch (artistNFTs.get(caller)) {
      case (null) { artistNFTs.put(caller, [nft.id]);};
      case (?nftArray) { artistNFTs.put(caller, Array.append<Text>(nftArray, [nft.id])); }
    };
    // nftList := Array.append<Text>(nftList, [nft.id]);
    nft.id;
  };

  public shared({caller}) func mintTicketNFT(metadata: TicketMetaData) : async Text {
    // assert(isStringEmpty(metadata.name), "Name must be not empty");
    // assert(metadata.price > 0, "Price must be greater than 0");

    let now = Time.now();
    let nft : NFT = {
      id = Principal.toText(caller) # "-" # metadata.name # "-" # (Int.toText(now));
      owner = caller;
      productType = "ticket";
    };

    let ticket : TicketMetaData = {
      time = metadata.time;
      name = metadata.name;
      location = metadata.location;
      description = metadata.description;
      totalSupply = metadata.totalSupply;
      price = metadata.price;
      loyalty = metadata.loyalty;
      status = metadata.status;
      schedule = metadata.schedule;
    };
    
    nfts.put(nft.id, nft);
    ticketNfts.put(nft.id, ticket);
    switch (artistNFTs.get(caller)) {
      case (null) { artistNFTs.put(caller, [nft.id]); };
      case (?nftArray) { artistNFTs.put(caller, Array.append<Text>(nftArray, [nft.id])); }
    };
    // nftList := Array.append<NFT>(nfts, [nft.id]);
    nft.id;
  };

  // Buy an NFT
  public shared({ caller }) func purchaseSong(id : Text): async () {
    let owner : Principal = caller;
    // assert(nfts.contains(id), "NFT does not exist");
    // assert(Array.find((x) => x == id, fanNFTWallet[owner]) == null, "Buyer already purchased the NFT");
    switch (await getSongMetadata(id)) {
      case (null) { return; };
      case (?metadata) {
        // assert(metadata.status == "active", "NFT is not available for sale");
        let amountToSend = await platformDeduction(metadata.price - (FEE * 2)); 
        var count : Nat64 = 0;
        for (collabs in Iter.fromArray(metadata.loyalty)) {
          let participantsCut : Nat64 = await getDeductedAmount(amountToSend - (FEE * count), collabs.participantPercentage);
          switch(await transfer(collabs.participantID, participantsCut)){
              case(#ok(res)){ 
                Debug.print("Paid artist: " # debug_show collabs.participantID #" amount: "# debug_show participantsCut #  " in block " # debug_show res);
                // await addToContentPaymentMap(id, collabs.participantID, ticker, caller, Nat64.toNat(participantsCut));
              }; case(#err(msg)){   throw Error.reject("Unexpected error: " # debug_show msg);    };
            };
          count := count + 1;
        }
      };
    };
  };

  public func getSongMetadata(id : Text) : async ?SongMetaData {
    // assert(nfts.contains(id), "NFT does not exist");
    // assert(getProductType(id) != "song", "Not song NFT");
    return songNfts.get(id);
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
}
