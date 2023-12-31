import Principal "mo:base/Principal";
import Array "mo:base/Array";
import Result "mo:base/Result";
import Time "mo:base/Time";
import Text "mo:base/Text";
import Int "mo:base/Int";
import Iter "mo:base/Iter";
import Cycles "mo:base/ExperimentalCycles";
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
import Buffer "mo:base/Buffer";
import Hex "./utils/Hex";
import Map  "mo:stable-hash-map/Map";
import Nat32 "mo:base/Nat32";
import Nat "mo:base/Nat";
import Prim "mo:⛔";

// Define the smart contract
shared({caller = managerCanister}) actor class TicketNFT(ticketMetaData: ?T.TicketMetaData, artistAccount: Principal) = this {
  type TransferArgs = T.TransferArgs;
  type GetBlocksArgs = T.GetBlocksArgs;
  type Result_1 = T.Result_1;
  type BinaryAccountBalanceArgs = T.BinaryAccountBalanceArgs;
  type QueryBlocksResponse = T.QueryBlocksResponse;
  type Tokens = T.Tokens;
  type AccountIdentifier = T.AccountIdentifier;
  type TicketMetaData = T.TicketMetaData;
  type ArtistID = T.ArtistID;
  type FanID = T.FanID;
  type Percentage = T.Percentage;
  type CanisterId                = T.CanisterId;
  type Participants = T.Participants;
  type FanToTime = Map.Map<Principal, (Int, Nat, Text)>;
  type ArtistToFan = Map.Map<ArtistID, FanToTime>;
  type TokenIndex = T.TokenIndex;
  type TokenIdentifier = T.TokenIdentifier;
  type CommonError = T.CommonError;
  type ExtMetadata = T.ExtMetadata;
  type StatusRequest = T.StatusRequest;
  type StatusResponse = T.StatusResponse;


  stable var MAX_CANISTER_SIZE: Nat =     48_000_000_000; // <-- approx. 40GB
  stable var CYCLE_AMOUNT : Nat     =    100_000_000_000;
  let maxCycleAmount                = 20_000_000_000_000;
  let top_up_amount                 = 10_000_000_000_000;
  
  let Ledger = actor "bkyz2-fmaaa-aaaaa-qaaaq-cai" : actor {
        query_blocks : shared query GetBlocksArgs -> async QueryBlocksResponse;
        transfer : shared TransferArgs -> async  Result_1;
        account_balance : shared query BinaryAccountBalanceArgs -> async Tokens;
    };
  let FEE : Nat64 = 10000;
  let { ihash; nhash; thash; n32hash; phash; calcHash } = Map;
  
  let marketplaceFee = 10;
  let marketplaceFeeRecipient = Principal.fromText("c2v5t-vzv25-xvigb-jhc7d-whtnk-xhgrc-cesv5-lrnrp-grfrj-i6j3z-aae");

  private var txNo : Nat64 = 0;
  stable var owner: Principal = artistAccount;
  stable var _minter: Principal = artistAccount;
  stable var canisterTicket: ?TicketMetaData = ticketMetaData;
  private stable var _nextTokenId : TokenIndex  = 0;

  private var fanNFTWallet = Map.new<Principal, [Text]>(phash);
  private var contentPaymentMap = Map.new<Text, ArtistToFan>(thash); 

  private stable var _registry = Map.new<TokenIndex, Principal>(n32hash);
  private stable var _supply = 0;
  private stable var _owners = Map.new<Principal, [TokenIndex]>(phash);
  private stable var _tokenMetadata  = Map.new<TokenIndex, ExtMetadata>(n32hash);

  public query func getFanTickets(fan: Principal) : async ?[Text] {
    return Map.get(fanNFTWallet, phash, fan);
  };

  stable var initialised: Bool = false;

  public func initCanister() :  async(Bool) {
    assert(initialised == false);
    switch(ticketMetaData){
      case(?data) {
        initialised := true;
        return true;
      };case null return false;
    };
  };
  
  // Mint an NFT
  public shared({caller}) func mintNFT(request: T.MintRequest) : async Text {
    var token: Text = "error";
    switch (canisterTicket) {
      case (null) { return "error"; };
      case (?metadata) {
        if (_supply >= metadata.totalSupply and metadata.totalSupply != 0) {
          return "total supply error";
        };
        // assert(metadata.status == "active", "NFT is not available for sale");
        let amountToSend = await platformDeduction(metadata.price - (FEE * 2)); 
        var count : Nat64 = 0;
        for (collabs in Iter.fromArray(metadata.royalty)) {
          let participantsCut : Nat64 = await getDeductedAmount(amountToSend - (FEE * count), collabs.participantPercentage);
          switch(await transfer(collabs.participantID, participantsCut)){
              case(#ok(res)){ 
                Debug.print("Paid artist: " # debug_show collabs.participantID #" amount: "# debug_show participantsCut #  " in block " # debug_show res);
                await addToContentPaymentMap(metadata.id, collabs.participantID, metadata.ticker, caller, Nat64.toNat(participantsCut));
              }; case(#err(msg)){   throw Error.reject("Unexpected error: " # debug_show msg);    };
            };
          count := count + 1;
        };
        switch (Map.get(fanNFTWallet, phash, owner)) {
          case (null) { var c = Map.put(fanNFTWallet, phash, caller, [metadata.id]); };
          case (?nftArray) { var c = Map.put(fanNFTWallet, phash, caller, Array.append<Text>(nftArray, [metadata.id])); };
        };
        
        switch (Map.get(_owners, phash, owner)) {
          case (null) { var c = Map.put(_owners, phash, caller, [_nextTokenId]); };
          case (?nftArray) { var c = Map.put(_owners, phash, caller, Array.append<TokenIndex>(nftArray, [_nextTokenId])); };
        };

        var d = Map.put(_registry, n32hash, _nextTokenId, request.to);

        let md : ExtMetadata = #nonfungible({
          metadata = request.metadata;
        }); 
        var e = Map.put(_tokenMetadata, n32hash, _nextTokenId, md);
      };
    };
    _supply := _supply + 1;
    _nextTokenId := _nextTokenId + 1;
    return token;
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

  public query func bearer(token : TokenIdentifier) : async Result.Result<Principal, CommonError> {
		if (T.TokenIdentifier.isPrincipal(token, Principal.fromActor(this)) == false) {
			return #err(#InvalidToken(token));
		};
		let tokenind = T.TokenIdentifier.getIndex(token);
    switch (Map.get(_registry, n32hash, tokenind)) {
      case (?token_owner) {
				return #ok(token_owner);
      };
      case (_) {
        return #err(#InvalidToken(token));
      };
    };
	};
  
  public query func getMinter() : async Principal {
    return _minter;
  };
  
  public func supply() : async Result.Result<Nat, CommonError> {
    return #ok(_supply);
  };

  public func getRegistry() : async [(TokenIndex, Principal)] {
    Iter.toArray(Map.entries(_registry));
  };

  public func getTokens() : async [(TokenIndex, ExtMetadata)] {
    var resp : Buffer.Buffer<(TokenIndex, ExtMetadata)> = Buffer.Buffer(0);
      for (e in Map.entries(_registry)) {
        resp.add((e.0, #nonfungible({ metadata = null })));
      };
      Buffer.toArray(resp);
  };

  public func tokens(aid : Principal) : async Result.Result<[TokenIndex], CommonError> {
    switch (Map.get(_owners, phash, aid)) {
      case (?tokens) return #ok(tokens);
      case (_) return #err(#Other("No tokens"));
    };
  };
  
  public query func metadata(token : TokenIdentifier) : async Result.Result<ExtMetadata, CommonError> {
    if (T.TokenIdentifier.isPrincipal(token, Principal.fromActor(this)) == false) {
			return #err(#InvalidToken(token));
		};
		let tokenind = T.TokenIdentifier.getIndex(token);
    switch (Map.get(_tokenMetadata, n32hash, tokenind)) {
      case (?token_metadata) {
				return #ok(token_metadata);
      };
      case (_) {
        return #err(#InvalidToken(token));
      };
    };
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

  private func getRemainingAfterDeduction(amount: Nat64, percent: Float) : async(Nat64){
    let priceFloat : Float = Float.fromInt(Nat64.toNat(amount));
    let deduction :  Float = priceFloat * percent;
    return Nat64.fromNat(Int.abs(Float.toInt(priceFloat - deduction)))
  };

  private func getDeductedAmount(amount: Nat64, percent: Float) : async(Nat64){
    let priceFloat : Float = Float.fromInt(Nat64.toNat(amount));
    return Nat64.fromNat(Int.abs(Float.toInt(priceFloat * percent)));
  };

  public shared({caller}) func getBalance(): async Tokens {
      var specifiedAccount = Account.accountIdentifier(caller, Account.defaultSubaccount());
      await Ledger.account_balance({ account = Blob.toArray(specifiedAccount) })
  };

  private func addToContentPaymentMap(id: Text, artist: ArtistID, ticker: Text, fan: Principal, amount: Nat) : async(){
    let now = Time.now();
    switch(Map.get(contentPaymentMap, thash, id)){
      case(?innerMap){
        switch(Map.get(innerMap, phash, artist)){
          case(?hasInit){
              var a = Map.put(hasInit, phash, fan, (now, amount, ticker));
          };
          case null {
            var x : FanToTime = Map.new<Principal, (Int, Nat, Text)>(phash);
            
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


  public func getAllContentPayments() : async [(Text, ArtistID, Principal, Int, Nat, Text)]{  

    var res = Buffer.Buffer<(Text, ArtistID, Principal, Int, Nat, Text)>(2);

    for((contentId, innerMap) in Map.entries(contentPaymentMap)){
      for((artistId, fanId) in Map.entries(innerMap)){
        for((k,v) in Map.entries(fanId)){
          var fanId: Principal = k;
          var timestamp: Int = v.0;
          var amount: Nat = v.1;
          var ticker: Text = v.2;
          res.add(contentId, artistId, fanId, timestamp, amount, ticker);
        }
      }
    };
    return Buffer.toArray(res);
  };

  public func getAllArtistContentPayments(artist: ArtistID) : async [(Text, Principal, Int, Nat, Text)]{  
    var res = Buffer.Buffer<(Text, Principal, Int, Nat, Text)>(2);

    for((key, value) in Map.entries(contentPaymentMap)){
      for((a, b) in Map.entries(value)){
        if(a == artist){
          for((k,v) in Map.entries(b)){
              var fanId: Principal = k;
              var timestamp: Int = v.0;
              var amount: Nat = v.1;
              var ticker: Text = v.2;
              res.add(key, fanId, timestamp, amount, ticker);
            }
        }
      }
    };
    return Buffer.toArray(res);
  };


  public func getAllFanContentPayments(fan: Principal) : async [(Text, Int, Nat, Text)]{ 
    
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

  public shared({caller}) func checkCyclesBalance () : async(){
    // assert(caller == owner or Utils.isManager(caller));
    Debug.print("creator of this smart contract: " #debug_show managerCanister);
    let bal = getCurrentCycles();
    Debug.print("Cycles Balance After Canister Creation: " #debug_show bal);
    if(bal < CYCLE_AMOUNT){
       await transferCyclesToThisCanister();
    };
  };



  private func wallet_receive() : async { accepted: Nat64 } {
    let available = Cycles.available();
    let accepted = Cycles.accept(Nat.min(available, top_up_amount));
    { accepted = Nat64.fromNat(accepted) };
  };

  private func transferCyclesToThisCanister() : async (){
    let self: Principal = Principal.fromActor(this);
    let can = actor(Principal.toText(managerCanister)): actor { 
      transferCycles: (CanisterId, Nat) -> async ();
    };
    let accepted = await wallet_receive();
    await can.transferCycles(self, Nat64.toNat(accepted.accepted));
  };



  public shared({caller}) func changeCycleAmount(amount: Nat) : (){
    // if (not Utils.isManager(caller)) {
    //   throw Error.reject("Unauthorized access. Caller is not the manager. " # Principal.toText(caller));
    // };
    CYCLE_AMOUNT := amount;
  };



  public shared({caller}) func changeCanisterSize(newSize: Nat) : (){
    // if (not Utils.isManager(caller)) {
    //   throw Error.reject("Unauthorized access. Caller is not the manager. " # Principal.toText(caller));
    // };
    MAX_CANISTER_SIZE := newSize;
  };

  private func getCurrentHeapMemory(): Nat {
    Prim.rts_heap_size();
  };

  private func getCurrentMemory(): Nat {
    Prim.rts_memory_size();
  };

  private func getCurrentCycles(): Nat {
    Cycles.balance();
  };

  public func getStatus(request: ?StatusRequest): async ?StatusResponse {
    switch(request) {
      case (?_request) {
          var cycles: ?Nat = null;
          if (_request.cycles) {
              cycles := ?getCurrentCycles();
          };
          var memory_size: ?Nat = null;
          if (_request.memory_size) {
              memory_size := ?getCurrentMemory();
          };
          var heap_memory_size: ?Nat = null;
          if (_request.heap_memory_size) {
              heap_memory_size := ?getCurrentHeapMemory();
          };
          return ?{
              cycles = cycles;
              memory_size = memory_size;
              heap_memory_size = heap_memory_size;
          };
      };
      case null return null;
    };
  };

  private func getAvailableMemoryCanister(canisterId: Principal) : async ?Nat{
    let can = actor(Principal.toText(canisterId)): actor { 
        getStatus: (?StatusRequest) -> async ?StatusResponse;
    };

    let request : StatusRequest = {
        cycles: Bool = false;
        heap_memory_size: Bool = false; 
        memory_size: Bool = true;
    };
    
    switch(await can.getStatus(?request)){
      case(?status){
        switch(status.memory_size){
          case(?memSize){
            let availableMemory: Nat = MAX_CANISTER_SIZE - memSize;
            return ?availableMemory;
          };
          case null null;
        };
      };
      case null null;
    };
  };
}
