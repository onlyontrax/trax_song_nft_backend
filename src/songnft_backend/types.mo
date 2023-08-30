import Hash "mo:base/Hash";
import Map "mo:base/HashMap";
import Principal "mo:base/Principal";
import Nat "mo:base/Nat";
import Nat32 "mo:base/Nat32";
import Time "mo:base/Time";
import Text "mo:base/Text";
import Iter "mo:base/Iter";
import Float "mo:base/Float";
import Result "mo:base/Result";
import Blob "mo:base/Blob";
import Array "mo:base/Array";
import IC "./ic.types";
import Nat8 "mo:base/Nat8";

module Types {
    public type UserId = Principal; 
    public type CanisterId = IC.canister_id;
    public type ArtistID = Principal;
    public type FanID = Principal;
    public type Percentage = Float;
    public type User = Principal;
    public type Participants = {
        participantID: ArtistID;
        participantPercentage: Percentage;
    };
    public type MintRequest = {
        to : User;
        metadata : ?Blob;
    };
    public type TokenIdentifier = Text;
    public type CommonError = {
        #InvalidToken: TokenIdentifier;
        #Other : Text;
    };
    public type TokenObj = {
        index : TokenIndex;
        canister : [Nat8];
    };
    public module TokenIdentifier = {
        private let tds : [Nat8] = [10, 116, 105, 100]; //b"\x0Atid"
        public let equal = Text.equal;
        public let hash = Text.hash;
        /*
        public func fromText(t : Text, i : TokenIndex) : TokenIdentifier {
            return fromPrincipal(Principal.fromText(t), i);
        };
        public func fromPrincipal(p : Principal, i : TokenIndex) : TokenIdentifier {
            return fromBlob(Principal.toBlob(p), i);
        };
        public func fromBlob(b : Blob, i : TokenIndex) : TokenIdentifier {
            return fromBytes(Blob.toArray(b), i);
        };
        public func fromBytes(c : [Nat8], i : TokenIndex) : TokenIdentifier {
            let bytes : [Nat8] = Array.append(Array.append(tds, c), nat32tobytes(i));
            return Hex.encode(Array.append(crc, bytes));
        };
        */
        //Coz can't get principal directly, we can compare the bytes
        public func isPrincipal(tid : TokenIdentifier, p : Principal) : Bool {
            let tobj = decode(tid);
            return Blob.equal(Blob.fromArray(tobj.canister), Principal.toBlob(p));
        };
        public func getIndex(tid : TokenIdentifier) : TokenIndex {
            let tobj = decode(tid);
            tobj.index;
        };
        public func decode(tid : TokenIdentifier) : TokenObj {
            let bytes = Blob.toArray(Principal.toBlob(Principal.fromText(tid)));
            var index : Nat8 = 0;
            var _canister : [Nat8] = [];
            var _token_index : [Nat8] = [];
            var _tdscheck : [Nat8] = [];
            var length : Nat8 = 0;
            for (b in bytes.vals()) {
            length += 1;
            if (length <= 4) {
                _tdscheck := Array.append(_tdscheck, [b]);
            };
            if (length == 4) {
                if (Array.equal(_tdscheck, tds, Nat8.equal) == false) {
                return {
                    index = 0;
                    canister = bytes;
                };
                };
            };
            };
            for (b in bytes.vals()) {
            index += 1;
            if (index >= 5) {
                if (index <= (length - 4)) {            
                _canister := Array.append(_canister, [b]);
                } else {
                _token_index := Array.append(_token_index, [b]);
                };
            };
            };
            let v : TokenObj = {
            index = bytestonat32(_token_index);
            canister = _canister;
            };
            return v;
        };

        private func bytestonat32(b : [Nat8]) : Nat32 {
            var index : Nat32 = 0;
            Array.foldRight<Nat8, Nat32>(b, 0, func (u8, accum) {
            index += 1;
            accum + Nat32.fromNat(Nat8.toNat(u8)) << ((index-1) * 8);
            });
        };
        private func nat32tobytes(n : Nat32) : [Nat8] {
            if (n < 256) {
            return [1, Nat8.fromNat(Nat32.toNat(n))];
            } else if (n < 65536) {
            return [
                2,
                Nat8.fromNat(Nat32.toNat((n >> 8) & 0xFF)), 
                Nat8.fromNat(Nat32.toNat((n) & 0xFF))
            ];
            } else if (n < 16777216) {
            return [
                3,
                Nat8.fromNat(Nat32.toNat((n >> 16) & 0xFF)), 
                Nat8.fromNat(Nat32.toNat((n >> 8) & 0xFF)), 
                Nat8.fromNat(Nat32.toNat((n) & 0xFF))
            ];
            } else {
            return [
                4,
                Nat8.fromNat(Nat32.toNat((n >> 24) & 0xFF)), 
                Nat8.fromNat(Nat32.toNat((n >> 16) & 0xFF)), 
                Nat8.fromNat(Nat32.toNat((n >> 8) & 0xFF)), 
                Nat8.fromNat(Nat32.toNat((n) & 0xFF))
            ];
            };
        };
    };
    public type TokenIndex = Nat32;
    public type FileExtension = {
      #jpeg;
      #jpg;
      #png;
      #gif;
      #svg;
      #mp3;
      #wav;
      #aac;
      #mp4;
      #avi;
    };
    public type SongMetaData = {
        id: Text;
        name: Text;
        description: Text;
        totalSupply: Nat;
        price: Nat64;
        ticker: Text;
        royalty: [Participants];
        status: Text;
        schedule: Time.Time;
        logo: Blob;
        chunkCount: Nat64;
        size: Nat64;
        extension: FileExtension;
    };
    public type TicketMetaData = {
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
        logo: Blob;
    };

    // Ext Common's Metadata
    public type ExtMetadata = {
        #fungible : {
        name : Text;
        symbol : Text;
        decimals : Nat8;
        metadata : ?Blob;
        };
        #nonfungible : {
        metadata : ?Blob;
        };
    };

    public type SubAccount = Blob;
    public type SubaccountNat8Arr = [Nat8];
    public type Memo = Nat64;
    public type BlockIndex = Nat64;

    public type Tokens = {
        e8s : Nat64;
    };

    public type TimeStamp = {
        timestamp_nanos : Nat64;
    };

    public type BlobAccountIdentifier = Blob;

    public type TransferArgs = {
        to : [Nat8];
        fee : Tokens;
        memo : Nat64;
        from_subaccount : ?[Nat8];
        created_at_time : ?TimeStamp;
        amount : Tokens;
    };

    public type BinaryAccountBalanceArgs = {
        account : [Nat8];
    };

    public type TransferError_1 = {
        #TxTooOld : { allowed_window_nanos : Nat64 };
        #BadFee : { expected_fee : Tokens };
        #TxDuplicate : { duplicate_of : Nat64 };
        #TxCreatedInFuture;
        #InsufficientFunds : { balance : Tokens };
    };

    public type Result_1 = {
        #Ok : Nat64;
        #Err : TransferError_1;
    };

    public type GetBlocksArgs = {
        start : Nat64;
        length : Nat64;
    };

    public type QueryBlocksResponse = {
        certificate : ?[Nat8];
        blocks : [CandidBlock];
        chain_length : Nat64;
        first_block_index : Nat64;
        archived_blocks : [ArchivedBlocksRange];
    };

    public type ArchivedBlocksRange = {
        callback : shared query GetBlocksArgs -> async {
            #Ok : BlockRange;
            #Err : GetBlocksError;
        };
        start : Nat64;
        length : Nat64;
    };

    public type GetBlocksError = {
        #BadFirstBlockIndex : {
            requested_index : Nat64;
            first_valid_index : Nat64;
        };
        #Other : { error_message : Text; error_code : Nat64 };
    };

    public type CandidBlock = {
        transaction : CandidTransaction;
        timestamp : TimeStamp;
        parent_hash : ?[Nat8];
    };

    public type CandidTransaction = {
        memo : Nat64;
        icrc1_memo : ?[Nat8];
        operation : ?CandidOperation;
        created_at_time : TimeStamp;
    };

    public type CandidOperation = {
        #Approve : {
            fee : Tokens;
            from : [Nat8];
            allowance_e8s : Int;
            expires_at : ?TimeStamp;
            spender : [Nat8];
        };
        #Burn : { from : [Nat8]; amount : Tokens };
        #Mint : { to : [Nat8]; amount : Tokens };
        #Transfer : {
            to : [Nat8];
            fee : Tokens;
            from : [Nat8];
            amount : Tokens;
        };
        #TransferFrom : {
            to : [Nat8];
            fee : Tokens;
            from : [Nat8];
            amount : Tokens;
            spender : [Nat8];
        };
    };

    public type BlockRange = {
        blocks : [CandidBlock];
    };

    type QueryArchiveError = {
        // [GetBlocksArgs.from] argument was smaller than the first block
        // served by the canister that received the request.
        #BadFirstBlockIndex : {
            requested_index : BlockIndex;
            first_valid_index : BlockIndex;
        };

        // Reserved for future use.
        #Other : {
            error_code : Nat64;
            error_message : Text;
        };
    };

    public type Block = {
        parent_hash : ?Blob;
        transaction : Transaction;
        timestamp : TimeStamp;
    };

    type Operation = {
        #Mint : {
            to : BlobAccountIdentifier;
            amount : Tokens;
        };
        #Burn : {
            from : BlobAccountIdentifier;
            amount : Tokens;
        };
        #Transfer : {
            from : BlobAccountIdentifier;
            to : BlobAccountIdentifier;
            amount : Tokens;
            fee : Tokens;
        };
    };

    type Transaction = {
        memo : Memo;
        operation : ?Operation;
        created_at_time : TimeStamp;
    };

    public type AccountIdentifier = {
        #text : Text;
        #principal : Principal;
        #blob : Blob;
    };

    // #region accountIdentifierToBlob
    public type AccountIdentifierToBlobArgs = {
        accountIdentifier : AccountIdentifier;
        canisterId : ?Principal;
    };
    public type AccountIdentifierToBlobResult = Result.Result<AccountIdentifierToBlobSuccess, AccountIdentifierToBlobErr>;
    public type AccountIdentifierToBlobSuccess = Blob;
    public type AccountIdentifierToBlobErr = {
        message : ?Text;
        kind : {
            #InvalidAccountIdentifier;
            #Other;
        };
    };
    // #endregion

    // #region accountIdentifierToText
    public type AccountIdentifierToTextArgs = {
        accountIdentifier : AccountIdentifier;
        canisterId : ?Principal;
    };
    public type AccountIdentifierToTextResult = Result.Result<AccountIdentifierToTextSuccess, AccountIdentifierToTextErr>;
    public type AccountIdentifierToTextSuccess = Text;
    public type AccountIdentifierToTextErr = {
        message : ?Text;
        kind : {
            #InvalidAccountIdentifier;
            #Other;
        };
    };
    // #endregion

    public type StatusRequest = {
        cycles: Bool;
        memory_size: Bool;
        heap_memory_size: Bool;
    };

    public type StatusResponse = {
        cycles: ?Nat;
        memory_size: ?Nat;
        heap_memory_size: ?Nat;
    }; 




    public type Timestamp = Int;
    
    public type ContentId = Text; // chosen by createVideo
    public type VideoId = Text; // chosen by createVideo
    public type ChunkId = Text; // VideoId # (toText(ChunkNum))
    
    public type ProfilePhoto = Blob; // encoded as a PNG file
    public type CoverPhoto = Blob;

    // public type Thumbnail = Blob; // encoded as a PNG file
    public type ChunkData = Blob; // encoded as ???
    
    public type Account = {
        owner : Principal;
        subaccount : ?SubAccount;
    };
};
