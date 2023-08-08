import { Actor, HttpAgent } from "@dfinity/agent";
import { createActor, canisterId } from "../../declarations/songnft_backend";
import { createActor as createTicketActor, canisterId as TicketCanisterId } from "../../declarations/ticketnft_backend";
import { createActor as createLedgerActor, canisterId as LedgerCanisterId } from '../../declarations/ledger';
import { AuthClient } from "@dfinity/auth-client";
const authClient = await AuthClient.create();
// Your application's name (URI encoded)
const APPLICATION_NAME = "Your%20Application%20Name";

// URL to 37x37px logo of your application (URI encoded)
const APPLICATION_LOGO_URL = "https://nfid.one/icons/favicon-96x96.png";

const AUTH_PATH = "/authenticate/?applicationName="+APPLICATION_NAME+"&applicationLogo="+APPLICATION_LOGO_URL+"#authorize";

// Replace https://identity.ic0.app with NFID_AUTH_URL
// as the identityProvider for authClient.login({}) 
const NFID_AUTH_URL = "https://nfid.one" + AUTH_PATH;
const LOCAL_IDENTITY_PROVIDER = "http://127.0.0.1:8006/?canisterId=bkyz2-fmaaa-aaaaa-qaaaq-cai";

var songnft_backend;
var ledgerActor;
var ticketnft_backend;

authClient.login({
  identityProvider: LOCAL_IDENTITY_PROVIDER,
  // 7 days in nanoseconds
  maxTimeToLive: BigInt(7 * 24 * 60 * 60 * 1000 * 1000 * 1000),
  onSuccess: async () => {
    alert("success");

    var identity = await authClient.getIdentity();
    const agent = new HttpAgent({ identity });
    agent.fetchRootKey().then(async (res) => {
      // 
      
      
      
    }).catch((err) => {
      console.warn(
        "Unable to fetch root key. Check to ensure that your local replica is running"
      );
      console.error(err);
    });
    songnft_backend = createActor(canisterId, {
      agent
    });
    ledgerActor = createLedgerActor(LedgerCanisterId, {
      agent
    });
    ticketnft_backend = createTicketActor(TicketCanisterId, {
      agent
    });
    console.log(ledgerActor);
  },
});

document.getElementById("mint_song_form").addEventListener("submit", async (e) => {
  e.preventDefault();
  const button = e.target.querySelector("button");

  const name = document.getElementById("name").value.toString();
  const description = document.getElementById("description").value.toString();
  const totalSupply = parseInt(document.getElementById("totalSupply").value.toString());
  const price = parseInt(document.getElementById("price").value.toString());

  button.setAttribute("disabled", true);

  
  

  // Interact with foo actor, calling the greet method
  const id = await songnft_backend.mintSongNFT({
    id: "0",
    name,
    description,
    totalSupply,
    royalty: [
      {
        participantID: await songnft_backend.getCallerId(),
        participantPercentage: 1,
      }
    ],
    price,
    status: 'active',
    schedule: 0,
    ticker: 'ICP'
  });
  document.getElementById("mint_song_result").innerHTML = "New Song NFT ID: " + id;

  button.removeAttribute("disabled");

  return false;
});

document.getElementById("get_song_list").addEventListener("click", async (e) => {
  e.preventDefault();
  var nft_list = await songnft_backend.getAllSongNFTs();
  var list = "";
  for (var nft of nft_list) {
     list += `<p>Id: ${nft[0]}, Name: ${nft[1]}, Description: ${nft[2]}, Price: ${nft[4]}</p>`;
  }
  document.getElementById("song_nft_list").innerHTML = list;
});

document.getElementById("purchase_song_form").addEventListener("submit", async (e) => {
  e.preventDefault();
  // 
  // 
  var song_id = document.getElementById("song_id").value;
  var song = await songnft_backend.getSongMetadata(song_id);
  
  var amountToSend = song[0].price;
  const uuid = BigInt(Math.floor(Math.random() * 1000));
  const txTime = {
    timestamp_nanos: BigInt(Date.now() * 1000000)
  };
  var result = await ledgerActor.transfer({
    memo: uuid,
    amount: { e8s: amountToSend },
    fee: { e8s: BigInt(10000) },
    from_subaccount: [],
    to: await songnft_backend.candidAccountIdentifierToBlob(process.env.SONGNFT_BACKEND_CANISTER_ID),
    created_at_time: [txTime]
  });
  
  await songnft_backend.purchaseSong(song_id);
  document.getElementById("purchase_song_result").innerHTML = "Successfully purchased";
});

document.getElementById("fan_wallet_form").addEventListener("submit", async (e) => {
  e.preventDefault();
  // 
  // 
  // var fan_id = document.getElementById("fan_id").value;
  var nfts = (await songnft_backend.getFanSongs(await songnft_backend.getCallerId()));
  
  var list = "";
  for (var nft of nfts[0]) {
    
     list += `<p>Id: ${nft}</p>`;
  }
  
  document.getElementById("fan_wallet_result").innerHTML = list;
});


document.getElementById("mint_ticket_form").addEventListener("submit", async (e) => {
  e.preventDefault();
  const button = e.target.querySelector("button");

  const name = document.getElementById("ticket_name").value.toString();
  const location = document.getElementById("ticket_location").value.toString();
  const event_date = document.getElementById("event_date").value.toString();
  const event_time = document.getElementById("event_time").value.toString();
  const description = document.getElementById("ticket_description").value.toString();
  const totalSupply = parseInt(document.getElementById("ticket_totalSupply").value.toString());
  const price = parseInt(document.getElementById("ticket_price").value.toString());

  button.setAttribute("disabled", true);

  // Interact with foo actor, calling the greet method
  const id = await ticketnft_backend.mintTicketNFT({
    id: "0",
    name,
    description,
    totalSupply,
    location,
    eventDate: event_date,
    eventTime: event_time,
    royalty: [
      {
        participantID: await ticketnft_backend.getCallerId(),
        participantPercentage: 1,
      }
    ],
    price,
    status: 'active',
    schedule: 0,
    ticker: 'ICP'
  });
  document.getElementById("mint_ticket_result").innerHTML = "New Ticket NFT ID: " + id;

  button.removeAttribute("disabled");

  return false;
});

document.getElementById("get_ticket_list").addEventListener("click", async (e) => {
  e.preventDefault();
  var nft_list = await ticketnft_backend.getAllTicketNFTs();
  var list = "";
  for (var nft of nft_list) {
     list += `<p>Id: ${nft[0]}, Name: ${nft[1]}, Location: ${nft[2]}, Description: ${nft[5]}, Event Date: ${nft[3]}, Event Time: ${nft[4]}, Price: ${nft[7]}</p>`;
  }
  document.getElementById("ticket_nft_list").innerHTML = list;
});

document.getElementById("purchase_ticket_form").addEventListener("submit", async (e) => {
  e.preventDefault();
  var ticket_id = document.getElementById("ticket_id").value;
  var song = await ticketnft_backend.getTicketMetaData(ticket_id);
  
  var amountToSend = song[0].price;
  const uuid = BigInt(Math.floor(Math.random() * 1000));
  const txTime = {
    timestamp_nanos: BigInt(Date.now() * 1000000)
  };
  var result = await ledgerActor.transfer({
    memo: uuid,
    amount: { e8s: amountToSend },
    fee: { e8s: BigInt(10000) },
    from_subaccount: [],
    to: await ticketnft_backend.candidAccountIdentifierToBlob(process.env.TICKETNFT_BACKEND_CANISTER_ID),
    created_at_time: [txTime]
  });
  
  await ticketnft_backend.purchaseTicket(ticket_id);
  document.getElementById("purchase_ticket_result").innerHTML = "Successfully purchased";
});

document.getElementById("fan_ticket_wallet_form").addEventListener("submit", async (e) => {
  e.preventDefault();
  // 
  // 
  // var fan_id = document.getElementById("fan_id").value;
  var nfts = (await ticketnft_backend.getFanTickets(await ticketnft_backend.getCallerId()));
  
  var list = "";
  for (var nft of nfts[0]) {
    
     list += `<p>Id: ${nft}</p>`;
  }
  
  document.getElementById("fan_ticket_wallet_result").innerHTML = list;
});