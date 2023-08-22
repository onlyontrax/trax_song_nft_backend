import T "./types";
import Principal "mo:base/Principal";
import Cycles "mo:base/ExperimentalCycles";
import Int "mo:base/Int";
import Map "mo:stable-hash-map/Map";
import Time "mo:base/Time";
import Account "./utils/account";
import Array "mo:base/Array";
import Buffer "mo:base/Buffer";
import Hex "utils/Hex";
import Blob "mo:base/Blob";
import CanisterUtils "utils/canister.utils";
import WalletUtils "utils/wallet.utils";
import SongNFT "songs";
import TicketNFT "tickets";
import Debug "mo:base/Debug";
import IC "ic.types";
import Error "mo:base/Error";
import Prim "mo:⛔";

actor traxNFT {
    type SongMetaData = T.SongMetaData;
    type TicketMetaData = T.TicketMetaData;
    type AccountIdentifier = T.AccountIdentifier;
    type StatusRequest = T.StatusRequest;
    type StatusResponse = T.StatusResponse;
    type Tokens = T.Tokens;
    type NFT = {
        id: Text;
        owner: Principal;
        productType: Text;
        canisterId: Principal;
    };

    type IdToNFT = Map.Map<Text, NFT>;
    let { ihash; nhash; thash; phash; calcHash } = Map;

    private let ic : IC.Self = actor "aaaaa-aa";
    stable var MAX_CANISTER_SIZE: Nat = 48_000_000_000; // <-- approx. 48MB
    stable var CYCLE_AMOUNT : Nat = 1_000_000_000_000;
    
    private let canisterUtils : CanisterUtils.CanisterUtils = CanisterUtils.CanisterUtils();
    private let walletUtils : WalletUtils.WalletUtils = WalletUtils.WalletUtils();
      
    private var nfts = Map.new<Text, NFT>(thash);
    private var songNfts = Map.new<Text, SongMetaData>(thash);
    private var ticketNfts = Map.new<Text, TicketMetaData>(thash);
    private var artistSongNFTs = Map.new<Principal, [Text]>(phash);
    private var artistTicketNFTs = Map.new<Principal, [Text]>(phash);
    private var _owners = Map.new<Principal, IdToNFT>(phash);

    public query func getArtistSongs(artist: Principal) : async ?[Text] {
        return Map.get(artistSongNFTs, phash, artist);
    };

    public query func getArtistNfts(artist: Principal) : async [(Text, Text, Principal)] {
      var res = Buffer.Buffer<(Text, Text, Principal)>(2);

      switch (Map.get(_owners, phash, artist)) {
        case (null) {

        };
        case (?nfts) {
          for ((key, nft) in Map.entries(nfts)) {
            res.add(key, nft.productType, nft.canisterId);
          }
        };
      };

      return Buffer.toArray(res);
    };
    
    public shared({caller}) func createSong(userId: Principal, metadata: SongMetaData) : async (Principal) {
        let now = Time.now();
        let song : SongMetaData = {
            id = Principal.toText(caller) # "-" # metadata.name # "-" # (Int.toText(now));
            name = metadata.name;
            description = metadata.description;
            totalSupply = metadata.totalSupply;
            price = metadata.price;
            royalty = metadata.royalty;
            status = metadata.status;
            ticker = metadata.ticker;
            schedule = metadata.schedule;
            logo = metadata.logo;
            size = metadata.size;
            chunkCount = metadata.chunkCount;
            extension = metadata.extension;
        };

        // Create Song Canister
        Debug.print(debug_show Principal.toText(userId));
    
        Cycles.add(CYCLE_AMOUNT);
        var canisterId: ?Principal = null;
        let d = await SongNFT.SongNFT(?song, userId);
        canisterId := ?(Principal.fromActor(d));

        let bal = getCurrentCycles();
        Debug.print("Cycles Balance After Canister Creation: " #debug_show bal);

        if(bal < CYCLE_AMOUNT){
        // notify frontend that cycles is below threshold
        };


        switch (canisterId) {
            case null {
                throw Error.reject("Bucket init error, your canister could not be created.");
            };
            case (?canisterId) {
                let self: Principal = Principal.fromActor(traxNFT);

                let controllers: ?[Principal] = ?[canisterId, userId, self];
                
                await ic.update_settings(({canister_id = canisterId; 
                    settings = {
                        controllers = controllers;
                        freezing_threshold = null;
                        memory_allocation = null;
                        compute_allocation = null;
                    }}));


                let nft : NFT = {
                    id = song.id;
                    owner = userId;
                    productType = "song";
                    canisterId = canisterId;
                };
                var a = Map.put(nfts, thash, song.id, nft);
                var b = Map.put(songNfts, thash, song.id, song);
                switch (Map.get(artistSongNFTs, phash, userId)) {
                    case (null) { var c = Map.put(artistSongNFTs, phash, userId, [song.id]); };
                    case (?nftArray) { var c = Map.put(artistSongNFTs, phash, userId, Array.append<Text>(nftArray, [song.id])); };
                };
                switch (Map.get(_owners, phash, userId)) {
                  case (null) { 
                    var idtonft = Map.new<Text, NFT>(thash);
                    var c = Map.put(idtonft, thash, song.id, nft);
                    var d = Map.put(_owners, phash, userId, idtonft);
                  };
                  case (?nfts) {
                    var c = Map.put(nfts, thash, song.id, nft);
                    var d = Map.put(_owners, phash, userId, nfts);
                  };
                };

                return canisterId;
            };
        };
    };


    public shared({caller}) func createTicket(userId: Principal, metadata: TicketMetaData) : async (Principal) {
        let now = Time.now();
        
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
            logo = metadata.logo;
            size = metadata.size;
            chunkCount = metadata.chunkCount;
            extension = metadata.extension;
        };

        // Create Ticket Canister
        Debug.print(debug_show Principal.toText(userId));
    
        Cycles.add(CYCLE_AMOUNT);
        var canisterId: ?Principal = null;
        let d = await TicketNFT.TicketNFT(?ticket, userId);
        canisterId := ?(Principal.fromActor(d));

        let bal = getCurrentCycles();
        Debug.print("Cycles Balance After Canister Creation: " #debug_show bal);

        if(bal < CYCLE_AMOUNT){
        // notify frontend that cycles is below threshold
        };


        switch (canisterId) {
            case null {
                throw Error.reject("Bucket init error, your canister could not be created.");
            };
            case (?canisterId) {
                let self: Principal = Principal.fromActor(traxNFT);

                let controllers: ?[Principal] = ?[canisterId, userId, self];
                
                await ic.update_settings(({canister_id = canisterId; 
                    settings = {
                        controllers = controllers;
                        freezing_threshold = null;
                        memory_allocation = null;
                        compute_allocation = null;
                    }}));


                let nft : NFT = {
                    id = ticket.id;
                    owner = userId;
                    productType = "ticket";
                    canisterId = canisterId;
                };
                var a = Map.put(nfts, thash, ticket.id, nft);
                var b = Map.put(ticketNfts, thash, ticket.id, ticket);
                switch (Map.get(artistTicketNFTs, phash, userId)) {
                    case (null) { var c = Map.put(artistTicketNFTs, phash, userId, [ticket.id]); };
                    case (?nftArray) { var c = Map.put(artistTicketNFTs, phash, userId, Array.append<Text>(nftArray, [ticket.id])); };
                };
                switch (Map.get(_owners, phash, userId)) {
                  case (null) { 
                    var idtonft = Map.new<Text, NFT>(thash);
                    var c = Map.put(idtonft, thash, ticket.id, nft);
                    var d = Map.put(_owners, phash, userId, idtonft);
                  };
                  case (?nfts) {
                    var c = Map.put(nfts, thash, ticket.id, nft);
                    var d = Map.put(_owners, phash, userId, nfts);
                  };
                };
                return canisterId;
            };
        };
    };

    public query func getSongMetadata(id: Text) : async ?SongMetaData {
        return Map.get(songNfts, thash, id);
    };

    public query func getTicketMetaData(id : Text) : async ?TicketMetaData {
        // assert(nfts.contains(id), "NFT does not exist");
        // assert(getProductType(id) != "song", "Not song NFT");
        return Map.get(ticketNfts, thash, id);
    };

    public func getNFT(id: Text) : async ?NFT {
        return Map.get(nfts, thash, id);
    };

    public func getAllSongNFTs() : async [(Text, Text, Text, Nat, Nat64, Text)] {
        var res = Buffer.Buffer<(Text, Text, Text, Nat, Nat64, Text)>(2);
        for ((key, song) in Map.entries(songNfts)) {
            switch(await getNFT(key)) {
                case(?nft) {
                    res.add(key, song.name, song.description, song.totalSupply, song.price, song.ticker);
                };
                case (null) {

                };
            };
        };
        return Buffer.toArray(res);
    };

    public func getAllTicketNFTs() : async [(Text, Text, Text, Text, Text, Text, Nat, Nat64, Text)] {
        var res = Buffer.Buffer<(Text, Text, Text, Text, Text, Text, Nat, Nat64, Text)>(2);
        for ((key, ticket) in Map.entries(ticketNfts)) {
            switch(await getNFT(key)) {
                case(?nft) {
                    res.add(key, ticket.name, ticket.location, ticket.eventDate, ticket.eventTime, ticket.description, ticket.totalSupply, ticket.price, ticket.ticker);
                };
                case (null) {

                };
            };
        };
        return Buffer.toArray(res);
    };


    // Utility functions

    public func candidAccountIdentifierToBlob(canisterId: Text) : async Blob {
        return Account.accountIdentifier(Principal.fromText(canisterId), Account.defaultSubaccount());
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

  public func accountIdentifierToBlobFromText (accountIdentifier : AccountIdentifier) : async T.AccountIdentifierToBlobResult {
    await accountIdentifierToBlob({
      accountIdentifier;
      canisterId = ?Principal.fromActor(traxNFT);
    });
  };

  public shared({caller}) func getCallerId() : async Principal {
    caller;
  };


  public shared({caller}) func getCallerIdentifier(): async Blob {
    return Account.accountIdentifier(caller, Account.defaultSubaccount());
  };

  public shared({caller}) func getCallerIdentifierAsText(): async Text {
    return Hex.encode(Blob.toArray(Account.accountIdentifier(caller, Account.defaultSubaccount())));
  };


  // Canister functions

  public shared({caller}) func getAvailableMemoryCanister(canisterId: Principal) : async ?Nat{
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



  private func getCurrentHeapMemory(): Nat {
    Prim.rts_heap_size();
  };



  private func getCurrentMemory(): Nat {
    Prim.rts_memory_size();
  };



  private func getCurrentCycles(): Nat {
    Cycles.balance();
  };



  public shared({caller}) func cyclesBalance() : async (Nat) {
    return walletUtils.cyclesBalance();
  };
}