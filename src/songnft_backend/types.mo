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

module Types {
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
    public type TokenIdentifier  = Text;
    public type TokenIndex = Nat32;
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
};
