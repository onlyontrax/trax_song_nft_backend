import Cycles               "mo:base/ExperimentalCycles";
import Principal            "mo:base/Principal";
import Error                "mo:base/Error";
import Nat                  "mo:base/Nat";
import Debug                "mo:base/Debug";
import Text                 "mo:base/Text";
import T                    "./types";
import Hash                 "mo:base/Hash";
import Nat32                "mo:base/Nat32";
import Nat64                "mo:base/Nat64";
import Iter                 "mo:base/Iter";
import Float                "mo:base/Float";
import Time                 "mo:base/Time";
import Int                  "mo:base/Int";
import Result               "mo:base/Result";
import Blob                 "mo:base/Blob";
import Array                "mo:base/Array";
import Buffer               "mo:base/Buffer";
import Trie                 "mo:base/Trie";
import TrieMap              "mo:base/TrieMap";
import CanisterUtils        "utils/canister.utils";
import WalletUtils          "utils/wallet.utils";
import Prim                 "mo:⛔";
import Map                  "mo:stable-hash-map/Map";


actor class SongContentBucket(owner: Principal, manager: Principal) = this {

  type UserId                    = T.UserId;
  type ContentInit               = T.ContentInit;
  type ContentId                 = T.ContentId;
  type ContentData               = T.ContentData;
  type ChunkId                   = T.ChunkId;
  type CanisterId                = T.CanisterId;
  type ChunkData                 = T.ChunkData;
  type StatusRequest             = T.StatusRequest;
  type StatusResponse            = T.StatusResponse;
  type Thumbnail                 = T.Thumbnail;
  type Trailer                   = T.Trailer;
  
  let { ihash; nhash; thash; phash; calcHash } = Map;

  stable var canisterOwner: Principal = owner;
  stable var managerCanister: Principal = manager;
  stable var MAX_CANISTER_SIZE: Nat =     48_000_000_000; // <-- approx. 48GB
  stable var CYCLE_AMOUNT : Nat     =  1_000_000_000_000; // minimum amount of cycles needed to create new canister 
  let maxCycleAmount                = 20_000_000_000_000; // canister cycles capacity 
  let top_up_amount                 = 10_000_000_000_000;
  var VERSION: Nat = 1;

  private let canisterUtils : CanisterUtils.CanisterUtils = CanisterUtils.CanisterUtils();
  private let walletUtils : WalletUtils.WalletUtils = WalletUtils.WalletUtils();
  
  private var content = Map.new<ContentId, ContentData>(thash);
  private var chunksData = Map.new<ChunkId, ChunkData>(thash);

  stable var initialised: Bool = false;
  

  


// #region - CREATE & UPLOAD CONTENT
  public shared({caller}) func createContent(i : ContentInit) : async ?ContentId {
    // assert(caller == owner or Utils.isManager(caller));
    let now = Time.now();
    // let videoId = Principal.toText(i.userId) # "-" # i.name # "-" # (Int.toText(now));
    switch (Map.get(content, thash, i.contentId)) {
    case (?_) { throw Error.reject("Content ID already taken")};
    case null { 
       let a = Map.put(content, thash, i.contentId,
                        {
                          contentId = i.contentId;
                          userId = i.userId;
                          name = i.name;
                          createdAt = i.createdAt;
                          uploadedAt = now;
                          description =  i.description;
                          chunkCount = i.chunkCount;
                          tags = i.tags;
                          extension = i.extension;
                          size = i.size;
                        });
        await checkCyclesBalance();
       ?i.contentId
     };
    }
  };
  


  public shared({caller}) func putContentChunk(contentId : ContentId, chunkNum : Nat, chunkData : Blob) : async (){
      // assert(caller == owner or Utils.isManager(caller));
      let a = Map.put(chunksData, thash, chunkId(contentId, chunkNum), chunkData);
  };



  public shared({caller}) func getContentChunk(contentId : ContentId, chunkNum : Nat) : async ?Blob {
    // assert(caller == owner or Utils.isManager(caller));
    Map.get(chunksData, thash, chunkId(contentId, chunkNum));
  };



  private func chunkId(contentId : ContentId, chunkNum : Nat) : ChunkId {
    contentId # (Nat.toText(chunkNum))
  };



  public shared({caller}) func removeContent(contentId: ContentId, chunkNum : Nat) : async () {
    // assert(caller == owner or Utils.isManager(caller));
    let a = Map.remove(chunksData, thash, chunkId(contentId, chunkNum));
    let b = Map.remove(content, thash, contentId);
  };



  public shared({caller}) func getContentInfo(id: ContentId) : async ?ContentData{
    // assert(caller == owner or Utils.isManager(caller));
    Map.get(content, thash, id);
  };
// #endregion



  

  




// #region - UTILS
  public shared({caller}) func checkCyclesBalance () : async(){
    // assert(caller == owner or Utils.isManager(caller));
    Debug.print("creator of this smart contract: " #debug_show manager);
    let bal = getCurrentCycles();
    Debug.print("Cycles Balance After Canister Creation: " #debug_show bal);
    if(bal < CYCLE_AMOUNT){
       await transferCyclesToThisCanister();
    };
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



  public shared ({caller}) func transferFreezingThresholdCycles() : async () {
    // if (not Utils.isManager(caller)) {
    //   throw Error.reject("Unauthorized access. Caller is not a manager.");
    // };

    await walletUtils.transferFreezingThresholdCycles(caller);
  };



  private func wallet_receive() : async { accepted: Nat64 } {
    let available = Cycles.available();
    let accepted = Cycles.accept(Nat.min(available, top_up_amount));
    { accepted = Nat64.fromNat(accepted) };
  };



  public shared({caller}) func getPrincipalThis() :  async (Principal){
    // if (not Utils.isManager(caller)) {
    //   throw Error.reject("Unauthorized access. Caller is not a manager.");
    // };
    Principal.fromActor(this);
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
            case (null) {
                return null;
            };
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
        };
  };
  public query func version() : async Nat {
		return VERSION;
	}; 
// #endregion
  
}