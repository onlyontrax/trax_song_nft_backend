import { Actor, HttpAgent } from "@dfinity/agent";
// import { createActor, canisterId } from "../../declarations/songnft_backend";
import { createActor as createNftActor, canisterId as NftCanisterId } from "../../declarations/traxNFT";
import { createActor as createSongActor, canisterId as SongCanisterId } from "../../declarations/SongNFT";
import { createActor as createTicketActor, canisterId as TicketCanisterId } from "../../declarations/TicketNFT";
import { createActor as createLedgerActor, canisterId as LedgerCanisterId } from '../../declarations/ledger';
import { AuthClient } from "@dfinity/auth-client";
const authClient = await AuthClient.create();
// Your application's name (URI encoded)
const APPLICATION_NAME = "Trax NFT";
const MAX_CHUNK_SIZE = 1024 * 500;

// URL to 37x37px logo of your application (URI encoded)
const APPLICATION_LOGO_URL = "https://nfid.one/icons/favicon-96x96.png";

const AUTH_PATH = "/authenticate/?applicationName="+APPLICATION_NAME+"&applicationLogo="+APPLICATION_LOGO_URL+"#authorize";

// Replace https://identity.ic0.app with NFID_AUTH_URL
// as the identityProvider for authClient.login({}) 
const NFID_AUTH_URL = "https://nfid.one" + AUTH_PATH;
const LOCAL_IDENTITY_PROVIDER = "http://127.0.0.1:8006/?canisterId=" + process.env.INTERNET_IDENTITY_CANISTER_ID;

const b64toBlob = (b64Data, contentType = '', sliceSize = 512) => {
  const byteCharacters = window.atob(b64Data);
  const byteArrays = [];

  for (let offset = 0; offset < byteCharacters.length; offset += sliceSize) {
    const slice = byteCharacters.slice(offset, offset + sliceSize);

    const byteNumbers = new Array(slice.length);
    for (let i = 0; i < slice.length; i += 1) {
      byteNumbers[i] = slice.charCodeAt(i);
    }

    const byteArray = new Uint8Array(byteNumbers);
    byteArrays.push(byteArray);
  }
  const blob = new Blob(byteArrays, { type: contentType });
  return blob;
};

const encodeArrayBuffer = (file) => Array.from(new Uint8Array(file));

const getFileExtension = (type) => {
  switch (type) {
    case 'image/jpeg':
      return { jpeg: null };
    case 'image/gif':
      return { gif: null };
    case 'image/jpg':
      return { jpg: null };
    case 'image/png':
      return { png: null };
    case 'image/svg':
      return { svg: null };
    case 'video/avi':
      return { avi: null };
    case 'video/aac':
      return { aac: null };
    case 'video/mp4':
      return { mp4: null };
    case 'audio/wav':
      return { wav: null };
    case 'audio/mp3':
      return { mp3: null };
    default:
      return null;
  }
};


var fileType;
var songnft_backend;
var nft_backend;
var ledgerActor;
var ticketnft_backend;
var agent;
var logoBlob;

const initCanister = async (bucket, type) => {
  // console.log(idlFactory)
  try {
    let actor;
    if (type === 'song') {
      actor = await createSongActor(bucket, {
        agent
      });
    } else {
      actor = await createTicketActor(bucket, {
        agent
      });
    }

    const res = await actor.initCanister();
    console.log(`init canister res: ${res}`);
  } catch (err) {
    console.error(err);
  }
};

function handleSongFileChange(event) {
  console.log(`HERERE : ${event.target.files[0]}`);
  const file = event.target.files[0];
  // Make new FileReader
  const reader = new FileReader();
  // Convert the file to base64 text
  reader.readAsDataURL(file);
  reader.onloadend = () => {
    if (reader.result === null) {
      throw new Error('file empty...');
    }
    let encoded = reader.result.toString().replace(/^data:(.*,)?/, '');
    if ((encoded.length % 4) > 0) {
      encoded += '='.repeat(4 - (encoded.length % 4));
    }
    const blob = b64toBlob(encoded, file.type);
    console.log(blob);

    fileType = { // FILE READER INFO
      name: file.name,
      type: file.type,
      size: file.size,
      blob,
      file,
      width: file.width,
      height: file.height
    };

    console.log(file);
    console.log(`${file.name} | ${Math.round(file.size / 1000)} kB`);
  };
};

document.getElementById("song_file").onchange = (event) => {
  console.log(`HERERE : ${event.target.files[0]}`);
  const file = event.target.files[0];
  // Make new FileReader
  const reader = new FileReader();
  // Convert the file to base64 text
  reader.readAsDataURL(file);
  reader.onloadend = () => {
    if (reader.result === null) {
      throw new Error('file empty...');
    }
    let encoded = reader.result.toString().replace(/^data:(.*,)?/, '');
    if ((encoded.length % 4) > 0) {
      encoded += '='.repeat(4 - (encoded.length % 4));
    }
    const blob = b64toBlob(encoded, file.type);
    console.log(blob);

    fileType = { // FILE READER INFO
      name: file.name,
      type: file.type,
      size: file.size,
      blob,
      file,
      width: file.width,
      height: file.height
    };

    console.log(file);
    console.log(`${file.name} | ${Math.round(file.size / 1000)} kB`);
  };
};

document.getElementById("song_logo").onchange = (event) => {
  console.log(`HERERE : ${event.target.files[0]}`);
  const file = event.target.files[0];
  // Make new FileReader
  const reader = new FileReader();
  // Convert the file to base64 text
  reader.readAsDataURL(file);
  reader.onloadend = () => {
    if (reader.result === null) {
      throw new Error('file empty...');
    }
    let encoded = reader.result.toString().replace(/^data:(.*,)?/, '');
    if ((encoded.length % 4) > 0) {
      encoded += '='.repeat(4 - (encoded.length % 4));
    }
    const blob = b64toBlob(encoded, file.type);
    console.log(blob);

    logoBlob = blob;

    console.log(file);
    console.log(`${file.name} | ${Math.round(file.size / 1000)} kB`);
  };
};

document.getElementById("ticket_logo").onchange = (event) => {
  console.log(`HERERE : ${event.target.files[0]}`);
  const file = event.target.files[0];
  // Make new FileReader
  const reader = new FileReader();
  // Convert the file to base64 text
  reader.readAsDataURL(file);
  reader.onloadend = () => {
    if (reader.result === null) {
      throw new Error('file empty...');
    }
    let encoded = reader.result.toString().replace(/^data:(.*,)?/, '');
    if ((encoded.length % 4) > 0) {
      encoded += '='.repeat(4 - (encoded.length % 4));
    }
    const blob = b64toBlob(encoded, file.type);
    console.log(blob);

    logoBlob1 = blob;

    console.log(file);
    console.log(`${file.name} | ${Math.round(file.size / 1000)} kB`);
  };
};

const processAndUploadChunk = async (
  blob,
  byteStart,
  chunk,
  fileSize,
  canisterId
) => {
  const blobSlice = blob.slice(
    byteStart,
    Math.min(Number(fileSize), byteStart + MAX_CHUNK_SIZE),
    blob.type
  );

  const bsf = await blobSlice.arrayBuffer();
  const actor = await createBucketActor({
    idl: artistContentBucketIDL,
    canisterId: canisterId.toString()
  });

  console.log(`chunk: ${chunk}`);
  return actor.putContentChunk(fileId, BigInt(chunk), encodeArrayBuffer(bsf));
};

authClient.login({
  identityProvider: LOCAL_IDENTITY_PROVIDER,
  // 7 days in nanoseconds
  maxTimeToLive: BigInt(7 * 24 * 60 * 60 * 1000 * 1000 * 1000),
  onSuccess: async () => {
    alert("success");

    var identity = await authClient.getIdentity();
    agent = new HttpAgent({ identity });
    agent.fetchRootKey().then(async (res) => {
      // 
      
      
      
    }).catch((err) => {
      console.warn(
        "Unable to fetch root key. Check to ensure that your local replica is running"
      );
      console.error(err);
    });
    nft_backend = createNftActor(NftCanisterId, {
      agent
    });
    ledgerActor = createLedgerActor(LedgerCanisterId, {
      agent
    });
    console.log(nft_backend.getCallerId())
  },
});

document.getElementById("create_song_form").addEventListener("submit", async (e) => {
  e.preventDefault();
  const button = e.target.querySelector("button");

  const name = document.getElementById("name").value.toString();
  const description = document.getElementById("description").value.toString();
  const totalSupply = parseInt(document.getElementById("totalSupply").value.toString());
  const price = parseInt(document.getElementById("price").value.toString());

  button.setAttribute("disabled", true);
  const fileExtension = getFileExtension(fileType.type);
  const chunkCount = BigInt(Number(Math.ceil(fileType.size / MAX_CHUNK_SIZE)));

  console.log(await nft_backend.getCallerId());
  console.log(logoBlob);
  console.log(fileExtension);
  console.log(encodeArrayBuffer(await (new Response(logoBlob).arrayBuffer())));
  
  // Interact with foo actor, calling the greet method
  const id = await nft_backend.createSong(await nft_backend.getCallerId(), {
    id: "0",
    name,
    description,
    totalSupply,
    royalty: [
      {
        participantID: await nft_backend.getCallerId(),
        participantPercentage: 1,
      }
    ],
    price,
    status: 'active',
    schedule: 0,
    ticker: 'ICP',
    chunkCount,
    extension: fileExtension,
    size: fileType.size,
    logo: encodeArrayBuffer(await (new Response(logoBlob).arrayBuffer()))
  });
  console.log(id);
  document.getElementById("create_song_result").innerHTML = "New Song NFT with Canister ID: " + id;

  button.removeAttribute("disabled");

  return false;
});
const blobToImage = (blob) => {
  return new Promise(resolve => {
    const url = URL.createObjectURL(blob)
    let img = new Image()
    console.log(url);
    img.src = url
    resolve(img);
  })
}
document.getElementById("get_song_list").addEventListener("click", async (e) => {
  e.preventDefault();
  var nft_list = await nft_backend.getAllSongNFTs();
  console.log(nft_list);
  document.getElementById("song_nft_list").innerHTML = "";
  var list = "";
  for (var nft of nft_list) {
    var nft1 = await nft_backend.getNFT(nft[0]);
    var song = await nft_backend.getSongMetadata(nft[0]);
    var canisterId = nft1[0].canisterId.toString();
    list += `<p>Id: ${nft[0]}, Name: ${nft[1]}, Description: ${nft[2]}, Price: ${nft[4]}, Canister Id: ${nft[6]}</p>`;
    console.log(song[0].logo);
    var image = await blobToImage(new Blob([song[0].logo], {type: 'image/png'}));
    image.width = image.height = 100;
    document.getElementById("song_nft_list").appendChild(image);
    var description = `<p>Id: ${nft[0]}, Name: ${nft[1]}, Description: ${nft[2]}, Price: ${nft[4]}, Canister Id: ${nft[6]}</p>`;
    var desc_element = document.createElement("p");
    desc_element.innerHTML = description;
    document.getElementById("song_nft_list").appendChild(desc_element);
  }
});

document.getElementById("purchase_song_form").addEventListener("submit", async (e) => {
  e.preventDefault();
  const button = e.target.querySelector("button");
  button.setAttribute("disabled", true);
  document.getElementById("purchase_song_result").innerHTML = "";
  // 
  // 
  var song_id = document.getElementById("song_id").value;
  var song = await nft_backend.getSongMetadata(song_id);
  var nft = await nft_backend.getNFT(song_id);
  var canisterId = nft[0].canisterId.toString();

  console.log(nft, canisterId);
  
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
    to: await nft_backend.candidAccountIdentifierToBlob(canisterId),
    created_at_time: [txTime]
  });

  console.log(result);
  let actor = await createSongActor(canisterId, {
    agent
  });
  var res = await actor.mintNFT({
    to: await nft_backend.getCallerId(),
    metadata: []
  });
  console.log(res);
  document.getElementById("purchase_song_result").innerHTML = "Successfully purchased";
  button.removeAttribute("disabled");
});

document.getElementById("fan_wallet_form").addEventListener("submit", async (e) => {
  e.preventDefault();
  // 
  // 
  var song_id = document.getElementById("fan_song_id").value;
  var song = await nft_backend.getSongMetadata(song_id);
  var nft = await nft_backend.getNFT(song_id);
  var canisterId = nft[0].canisterId.toString();
  let actor = await createSongActor(canisterId, {
    agent
  });
  var nfts = (await actor.getTokens());

  console.log(nfts);
  
  var list = "";
  for (var nft of nfts) {
    
     list += `<p>Token Index: ${nft[0]}</p>`;
  }
  
  document.getElementById("fan_wallet_result").innerHTML = list;
});


document.getElementById("create_ticket_form").addEventListener("submit", async (e) => {
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
  const id = await ticketnft_backend.createTicket(
  await nft_backend.getCallerId(),
  {
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
    ticker: 'ICP',
    logo: encodeArrayBuffer(await (new Response(logoBlob1).arrayBuffer()))
  });
  document.getElementById("create_ticket_result").innerHTML = "New Ticket NFT ID: " + id;

  button.removeAttribute("disabled");

  return false;
});

document.getElementById("get_ticket_list").addEventListener("click", async (e) => {
  e.preventDefault();
  var nft_list = await ticketnft_backend.getAllTicketNFTs();
  var list = "";
  for (var nft of nft_list) {
     list += `<p>Id: ${nft[0]}, Name: ${nft[1]}, Location: ${nft[2]}, Description: ${nft[5]}, Event Date: ${nft[3]}, Event Time: ${nft[4]}, Price: ${nft[7]}, CanisterId: ${nft[9]}</p>`;
  }
  document.getElementById("ticket_nft_list").innerHTML = list;
});

document.getElementById("purchase_ticket_form").addEventListener("submit", async (e) => {
  e.preventDefault();
  var ticket_id = document.getElementById("ticket_id").value;
  var ticket = await ticketnft_backend.getTicketMetaData(ticket_id);
  var nft = await nft_backend.getNFT(ticket_id);
  var canisterId = nft[0].canisterId.toString();
  
  var amountToSend = ticket[0].price;
  const uuid = BigInt(Math.floor(Math.random() * 1000));
  const txTime = {
    timestamp_nanos: BigInt(Date.now() * 1000000)
  };
  var result = await ledgerActor.transfer({
    memo: uuid,
    amount: { e8s: amountToSend },
    fee: { e8s: BigInt(10000) },
    from_subaccount: [],
    to: await nft_backend.candidAccountIdentifierToBlob(canisterId),
    created_at_time: [txTime]
  });

  console.log(result);
  let actor = await createTicketActor(canisterId, {
    agent
  });
  var res = await actor.mintNFT({
    to: await nft_backend.getCallerId(),
    metadata: []
  });
  console.log(res);
  document.getElementById("purchase_ticket_result").innerHTML = "Successfully purchased";
});

document.getElementById("fan_ticket_wallet_form").addEventListener("submit", async (e) => {
  e.preventDefault();
  // 
  // 
  var fan_id = document.getElementById("fan_ticket_id").value;
  var nft = await nft_backend.getNFT(song_id);
  var canisterId = nft[0].canisterId.toString();
  let actor = await createTicketActor(canisterId, {
    agent
  });
  var nfts = (await actor.getTokens());
  
  var list = "";
  for (var nft of nfts) {
    
     list += `<p>Id: ${nft}</p>`;
  }
  
  document.getElementById("fan_ticket_wallet_result").innerHTML = list;
});