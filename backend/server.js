require('dotenv').config();

const express = require('express');
const cors = require('cors');
const OpenAI = require('openai');

const app = express();
const PORT = process.env.PORT || 3000;

const multer = require('multer');

const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY,
});

const FREE_MINI_MODEL = 'gpt-5.4-mini-2026-03-17';
const STRONG_MODEL = 'gpt-5.4-2026-03-05';

app.use(cors());
app.use(express.json());
const upload = multer({
  storage: multer.memoryStorage(),
});

app.get('/', (req, res) => {
  res.json({
    message: 'Pinori brain is awake ♡',
  });
});

async function freeFirstTextExtraction(input) {
  const response = await openai.responses.create({
    model: FREE_MINI_MODEL,

    input: `
You are Pinori's free-first location extraction assistant.

Read this travel-related input:

"${input}"

DO NOT search the web.

Your job is to decide whether the input itself contains enough
information to identify a specific real-world place.

There are three possible situations:

1. SPECIFIC PLACE WITH ENOUGH INFORMATION
Examples:
- a place name plus an address
- a place name plus a clear city/neighbourhood
- pasted social-media text that clearly names the venue
- a caption containing enough identifying information

Extract the information that is explicitly present or confidently
understood from the input.

2. RECOMMENDATION REQUEST
Examples:
- "find me a cute cafe in Sinsa"
- "recommend somewhere romantic in London"

Do NOT recommend somewhere yourself.
Set "needsWebSearch" to true.

3. UNCLEAR PLACE / SOCIAL LINK
Examples:
- a TikTok or Instagram URL with no useful place information
- vague text such as "this place looks amazing"

Do NOT guess.
Set "needsWebSearch" to true.

IMPORTANT:
- Never invent an address.
- Never invent a business.
- Do not claim something is verified.
- If an address is not supplied or confidently known, leave it empty.
- If you are uncertain which specific place is meant, use needsWebSearch true.

"category" must be exactly one of:

Cafe
Restaurant
Shopping
Beauty
Attraction
Museum
Park
Nightlife
Hotel
Transport
Other

Return ONLY valid JSON in exactly this shape:

{
  "needsWebSearch": true,
  "name": "",
  "city": "",
  "neighbourhood": "",
  "nearestStation": "",
  "category": "Other",
  "address": "",
  "localAddress": "",
  "imageUrl": "",
  "confidence": 0.0
}
`,
  });

  const result = JSON.parse(response.output_text);

  console.log(
    'FREE MINI TEXT RESULT:',
    result,
  );

  return result;
}

app.post('/extract-place', async (req, res) => {
  try {
    const { input } = req.body;

    if (!input) {
      return res.status(400).json({
        error: 'No input provided',
      });
    }

    const tripDestination = extractTripDestination(input);

console.log(
  'TRIP DESTINATION:',
  tripDestination || 'not provided',
);

    const freeResult = await freeFirstTextExtraction(input);

const freeResultMatchesDestination =
  placeMatchesDestination(
    tripDestination,
    freeResult,
  );

const canUseFreeResult =
  freeResult.needsWebSearch === false &&
  typeof freeResult.name === 'string' &&
  freeResult.name.trim().length > 0 &&
  Number(freeResult.confidence ?? 0) >= 0.85 &&
  freeResultMatchesDestination;

if (!freeResultMatchesDestination) {
  console.log(
    'FREE MINI LOCATION MISMATCH — escalating to web search...',
  );
}

if (canUseFreeResult) {
  console.log(
    'FREE MINI TEXT RESULT ACCEPTED — no web search needed ♡',
  );

  const {
    needsWebSearch,
    ...placeResult
  } = freeResult;

  return res.json(placeResult);
}

console.log(
  'FREE MINI NEEDS HELP — escalating to web search...',
);

 const response = await openai.responses.create({
  model: 'gpt-5.4',

  tools: [
    {
      type: 'web_search_preview',
    },
  ],

  tool_choice: 'required',

  input: `
You are Pinori's location extraction assistant.

The user gave this travel recommendation:

"${input}"

You MUST search the web before answering.

Your job:
1. Identify the specific real-world place.
2. Search the web to verify it.
3. Find a real street address if one can be verified.
4. Do not invent an address.

IMPORTANT FOR SOCIAL MEDIA LINKS:

If the supplied Instagram, TikTok, or other social-media page
cannot be opened directly, DO NOT immediately give up.

Instead:

- inspect the URL itself for useful clues
- extract the username/account name
- extract the video/post ID
- extract any search/query text from the URL
- search the web using combinations of those clues
- search for indexed references to the post
- search for the creator together with likely place names
- use snippets, reposts, search results, business pages,
  travel listings, and other reliable indexed sources
- try to identify the place indirectly even if the original
  social-media page is inaccessible

For example, for a TikTok URL containing:
@bananaakimm
7654920878928645397
seoul restaurant

you should search combinations such as:
"bananaakimm Seoul restaurant"
"bananaakimm 7654920878928645397"
and other relevant combinations before returning no result.

NEVER guess a place just because it appears related to the
creator, search query, neighbourhood, or general topic.

For identification requests, a place must have strong evidence
connecting it to the specific source.

For recommendation requests, choose one real place with strong
evidence that it matches the user's requested area, category,
and preferences.

There are two possible types of request:

1. PLACE IDENTIFICATION
If the user is trying to identify a specific place from a
caption, link, post, recommendation, or description:
- require strong evidence connecting the result to that specific place
- if multiple possible places are found and you cannot determine which one
  is intended, return an empty result

2. PLACE RECOMMENDATION
If the user is asking you to recommend somewhere, such as:
"a cute cafe in Sinsa-dong"
"a nice restaurant near Hongdae"
"somewhere romantic in London"

then:
- search the web for real places matching the request
- respect the requested city, neighbourhood, category, and vibe
- it is OK if multiple possible places exist
- choose ONE strong match
- verify that it is a real current place
- find a verified address
- return that place

If confidence would be below 0.75, return:

{
  "name": "",
  "city": "",
  "neighbourhood": "",
  "nearestStation": "",
  "category": "",
  "address": "",
  "confidence": 0.0
}

Prefer official business pages, official tourism pages,
reputable map/travel listings, or other reliable sources.

Set "imageUrl" to an empty string for now.
Do not invent or guess an image URL.

CATEGORY RULE:

"category" MUST be exactly one of these values:

Cafe
Restaurant
Shopping
Beauty
Attraction
Museum
Park
Nightlife
Hotel
Transport
Other

Map more specific descriptions into the closest category.

Examples:
- dessert cafe -> Cafe
- bakery cafe -> Cafe
- coffee shop -> Cafe
- barbecue restaurant -> Restaurant
- cocktail bar -> Nightlife
- clothing store -> Shopping
- observation deck -> Attraction

Never create a new category.

For places in countries that use a local writing system,
also find and verify the address in the local language.

For South Korea, "localAddress" should contain the verified
Korean address if available.

Example:
"address": "495 Tongsam-ro, Namsa-eup, Cheoin-gu, Yongin-si, Gyeonggi-do, South Korea"
"localAddress": "경기 용인시 처인구 남사읍 통삼로 495"

Do not translate or invent a local address.
If it cannot be verified, use an empty string.

Return ONLY valid JSON:

{
  "name": "",
  "city": "",
  "neighbourhood": "",
  "nearestStation": "",
  "category": "",
  "address": "",
  "localAddress": "",
  "imageUrl": "",
  "confidence": 0.0
}
`,
});

function extractTripDestination(input = '') {
  const patterns = [
    /Trip destination:\s*([^\n]+)/i,
    /The place should be relevant to this trip destination:\s*([^\n]+)/i,
  ];

  for (const pattern of patterns) {
    const match = input.match(pattern);

    if (match?.[1]) {
      return match[1].trim();
    }
  }

  return '';
}

function placeMatchesDestination(destination, place) {
  if (!destination) {
    return true;
  }

  const normalize = (value = '') =>
    value
      .toLowerCase()
      .normalize('NFD')
      .replace(/[\u0300-\u036f]/g, '')
      .replace(/[^a-z0-9가-힣\s]/g, ' ')
      .replace(/\s+/g, ' ')
      .trim();

  const destinationParts = destination
    .split(',')
    .map((part) => normalize(part))
    .filter(Boolean);

  const resultLocation = normalize(
    [
      place.city,
      place.neighbourhood,
      place.address,
      place.localAddress,
    ]
      .filter(Boolean)
      .join(' '),
  );

  // Not enough information to judge yet.
  if (!resultLocation) {
    return true;
  }

  if (destinationParts.length === 0) {
    return true;
  }

  // The first part should be the important destination:
  // London, Seoul, Tokyo, New York City, etc.
  const primaryDestination = destinationParts[0];

  if (resultLocation.includes(primaryDestination)) {
    return true;
  }

  // Allow common wording differences such as
  // "New York City" vs "New York".
  const simplifiedPrimary = primaryDestination
    .replace(
      /\b(city|island|province|state|prefecture|county|district)\b/g,
      '',
    )
    .replace(/\s+/g, ' ')
    .trim();

  if (
    simplifiedPrimary.length >= 3 &&
    resultLocation.includes(simplifiedPrimary)
  ) {
    return true;
  }

  return false;
}

    const text = response.output_text;

    const extractedPlace = JSON.parse(text);

console.log('RAW EXTRACTED PLACE:', extractedPlace);

const webResultMatchesDestination =
  placeMatchesDestination(
    tripDestination,
    extractedPlace,
  );

if (!webResultMatchesDestination) {
  console.log(
    'WEB RESULT REJECTED — destination mismatch:',
    {
      tripDestination,
      resultCity: extractedPlace.city,
      resultNeighbourhood: extractedPlace.neighbourhood,
      resultAddress: extractedPlace.address,
    },
  );

  return res.json({
    name: '',
    city: '',
    neighbourhood: '',
    nearestStation: '',
    category: '',
    address: '',
    localAddress: '',
    imageUrl: '',
    confidence: 0.0,
  });
}

console.log(
  'WEB RESULT DESTINATION MATCHED ♡',
);

res.json(extractedPlace);
  } catch (error) {
    console.error(error);

    res.status(500).json({
      error: 'Pinori could not extract the place',
    });
  }
});

app.post('/geocode-korea', async (req, res) => {
  try {
    const { address, name } = req.body;

    if (!address && !name) {
      return res.status(400).json({
        error: 'No address or place name provided',
      });
    }

    const headers = {
      Authorization: `KakaoAK ${process.env.KAKAO_REST_API_KEY}`,
    };

    // 1. Try exact address first
    if (address) {
      const addressResponse = await fetch(
        `https://dapi.kakao.com/v2/local/search/address.json?query=${encodeURIComponent(address)}`,
        { headers },
      );

      if (!addressResponse.ok) {
        const errorText = await addressResponse.text();

        console.error(
          'KAKAO ADDRESS ERROR:',
          addressResponse.status,
          errorText,
        );
      } else {
        const addressData = await addressResponse.json();

        if (
          addressData.documents &&
          addressData.documents.length > 0
        ) {
          const result = addressData.documents[0];

          return res.json({
            found: true,
            source: 'address',
            latitude: Number.parseFloat(result.y),
            longitude: Number.parseFloat(result.x),
          });
        }
      }
    }

    // 2. If address fails, search for the actual place
    if (name) {
      const keywordQuery = `${name} ${address ?? ''}`.trim();

console.log('KAKAO KEYWORD QUERY:', keywordQuery);

const keywordResponse = await fetch(
  `https://dapi.kakao.com/v2/local/search/keyword.json?query=${encodeURIComponent(keywordQuery)}`,
  { headers },
);

      if (!keywordResponse.ok) {
        const errorText = await keywordResponse.text();

        console.error(
          'KAKAO KEYWORD ERROR:',
          keywordResponse.status,
          errorText,
        );
      } else {
        const keywordData = await keywordResponse.json();

        console.log(
  'KAKAO KEYWORD RESULTS:',
  keywordData.documents?.map((place) => ({
    name: place.place_name,
    address: place.road_address_name || place.address_name,
    latitude: place.y,
    longitude: place.x,
  })),
);

        if (
          keywordData.documents &&
          keywordData.documents.length > 0
        ) {
          const result = keywordData.documents[0];

          return res.json({
            found: true,
            source: 'keyword',
            name: result.place_name,
            address: result.road_address_name || result.address_name,
            latitude: Number.parseFloat(result.y),
            longitude: Number.parseFloat(result.x),
          });
        }
      }
    }

    return res.json({
      found: false,
    });
  } catch (error) {
    console.error('KAKAO GEOCODING ERROR:', error);

    res.status(500).json({
      error: 'Kakao geocoding failed',
    });
  }
});

function doubleOrNull(value) {
  const parsed = Number.parseFloat(value);
  return Number.isFinite(parsed) ? parsed : null;
}

app.post(
  '/extract-place-image',
  upload.single('image'),
  async (req, res) => {
    try {
      if (!req.file) {
        return res.status(400).json({
          error: 'No image provided',
        });
      }

     let mimeType = req.file.mimetype;

if (
  !mimeType ||
  mimeType === 'application/octet-stream'
) {
  const lowerName =
    req.file.originalname.toLowerCase();

  if (lowerName.endsWith('.png')) {
    mimeType = 'image/png';
  } else if (
    lowerName.endsWith('.jpg') ||
    lowerName.endsWith('.jpeg')
  ) {
    mimeType = 'image/jpeg';
  } else if (lowerName.endsWith('.webp')) {
    mimeType = 'image/webp';
  }
}

const base64Image =
  req.file.buffer.toString('base64');

      const imageDataUrl =
        `data:${mimeType};base64,${base64Image}`;

      const response = await openai.responses.create({
  model: FREE_MINI_MODEL,

  input: [
          {
            role: 'user',
            content: [
              {
                type: 'input_text',
                text: `
You are Pinori's location extraction assistant.

Look at this travel/social-media screenshot.

Your job:
1. Identify the specific real-world place being shown or recommended.
2. Use visible clues such as:
   - captions
   - location tags
   - signs
   - usernames
   - place names
   - neighbourhood names
   - Korean or English text
3. Do NOT search the web. Use only information visible in the screenshot
   and your existing knowledge.
4. Extract the real-world place information as accurately as possible.
5. If an address is clearly visible in the screenshot, return it exactly.
6. If the place name is clear but the address is not confidently known,
   leave the address empty rather than inventing one.
5. Do NOT invent an address.

Focus on South Korea when relevant.

CONFIDENCE RULES:

Use confidence >= 0.85 only when the screenshot itself gives strong
identifying information such as:
- a clear place name
- a location tag
- a visible address
- a very clear caption identifying the venue

If the screenshot does not contain enough information to identify the
specific place confidently, use confidence below 0.85.

Do not pretend to have verified something on the web.

Set "imageUrl" to an empty string for now.
Do not invent or guess an image URL.

For places in countries that use a local writing system,
also return the verified native-language place name.

For South Korea:
- "name" should be the English/romanised place name
- "localName" should be the verified Korean place name

Example:
"name": "Arirang Dowon"
"localName": "아리랑도원"

If the native-language place name cannot be verified,
use an empty string.

Do not invent or translate the place name yourself.

For places in countries that use a local writing system,
also return the verified native-language address.

For South Korea:
- "address" should be the verified English/romanised address
- "localAddress" should be the verified Korean address

Example:

"address": "495 Tongsam-ro, Namsa-eup, Cheoin-gu, Yongin-si, Gyeonggi-do, South Korea",
"localAddress": "경기 용인시 처인구 남사읍 통삼로 495"

If a local-language address cannot be verified, use an empty string.
Do not invent or translate an address yourself.

Return ONLY valid JSON in exactly this shape:

{
  "name": "",
  "localName": "",
  "city": "",
  "neighbourhood": "",
  "nearestStation": "",
  "category": "",
  "address": "",
  "localAddress": "",
  "imageUrl": "",
  "confidence": 0.0
}

category must be one of:
Cafe, Restaurant, Shopping, Beauty, Attraction,
Museum, Park, Nightlife, Hotel, Transport, Other.

If a field cannot be verified, use an empty string.
confidence must be between 0 and 1.

`,
              },
              {
                type: 'input_image',
                image_url: imageDataUrl,
                detail: 'high',
              },
            ],
          },
        ],
      });

      const firstPassPlace =
  JSON.parse(response.output_text);

console.log(
  'FREE MINI IMAGE RESULT:',
  firstPassPlace,
);

const firstPassIsStrong =
  typeof firstPassPlace.name === 'string' &&
  firstPassPlace.name.trim().length > 0 &&
  Number(firstPassPlace.confidence ?? 0) >= 0.85;

if (firstPassIsStrong) {
  console.log(
    'FREE MINI RESULT ACCEPTED — no web search needed ♡',
  );

  return res.json(firstPassPlace);
}

console.log(
  'FREE MINI WAS UNSURE — escalating to web search...',
);

// Paid / tool-assisted fallback
const fallbackResponse =
  await openai.responses.create({
    model: STRONG_MODEL,

    tools: [
      {
        type: 'web_search',
      },
    ],

    input: [
      {
        role: 'user',
        content: [
          {
            type: 'input_text',
            text: `
You are Pinori's location verification assistant.

The first-pass image model could not confidently identify
this travel/social-media screenshot.

Its tentative result was:

${JSON.stringify(firstPassPlace, null, 2)}

Now use the screenshot AND web search to identify and verify
the specific real-world place.

Your job:
1. Inspect the screenshot carefully.
2. Search the web using any useful clues.
3. Identify the specific place.
4. Verify that the place really exists.
5. Find a verified street address.
6. Do not guess.
7. Prefer official business pages, tourism sites,
   reputable map listings, or other reliable sources.

For South Korean places:
- return the English/romanised name in "name"
- return the verified Korean name in "localName"
- return the English/romanised address in "address"
- return the verified Korean address in "localAddress"

CATEGORY RULE:

"category" MUST be exactly one of:

Cafe
Restaurant
Shopping
Beauty
Attraction
Museum
Park
Nightlife
Hotel
Transport
Other

Return ONLY valid JSON in exactly this shape:

{
  "name": "",
  "localName": "",
  "city": "",
  "neighbourhood": "",
  "nearestStation": "",
  "category": "",
  "address": "",
  "localAddress": "",
  "imageUrl": "",
  "confidence": 0.0
}

If the place still cannot be confidently identified,
return empty strings and confidence 0.0.
`,
          },
          {
            type: 'input_image',
            image_url: imageDataUrl,
            detail: 'high',
          },
        ],
      },
    ],
  });

const verifiedPlace =
  JSON.parse(fallbackResponse.output_text);

console.log(
  'WEB VERIFIED IMAGE RESULT:',
  verifiedPlace,
);

return res.json(verifiedPlace);
    } catch (error) {
      console.error(error);

      res.status(500).json({
        error:
            'Pinori could not extract the place from the image',
      });
    }
  },
);

app.post('/hey-girl', async (req, res) => {
  try {
    const {
      tripName,
      destination,
      localInsight,
      places,
    } = req.body;

    if (!destination) {
      return res.status(400).json({
        error: 'No trip destination provided',
      });
    }

    const placeSummary = Array.isArray(places)
  ? places
      .map(
        (place) =>
          `${place.name} | ${place.category} | ${place.neighbourhood} | ${
            place.visited ? 'VISITED' : 'NOT VISITED'
          }`,
      )
      .join('\n')
  : '';

    const response = await openai.responses.create({
  model: FREE_MINI_MODEL,

  input: `
You are the little travel companion inside an app called Pinori.

Write ONE short, casual observation about the user's saved trip.

Trip:
${tripName ?? ''}
Destination:
${destination}

Pinori already calculated this useful fact:
${localInsight ?? ''}

Saved places:
${placeSummary}

RULES:
- Base your response ONLY on the information above.
- Do not invent facts about the places.
- Do not recommend a new business or attraction.
- Pay attention to whether each place is VISITED or NOT VISITED.
- Never suggest visiting a place as a future plan if it is already marked VISITED.
- If useful, mention progress such as how many saved places have already been visited.
- If a nearby cluster contains both visited and unvisited places, distinguish between them.
- If all places in a useful cluster are already visited, treat it as something the user has completed rather than something they should do.
- You can celebrate places the user has visited, but keep it natural rather than congratulating them every time.
- Prioritise useful observations about what remains unvisited when that is more helpful.
- Keep it under about 35 words.
- Sound playful, warm and conversational.
- It should feel like a friend noticing something useful.
- Light phrases like "Girl..." or "👀" are fine, but don't force them every time.
- Do not say "As an AI".
- Return ONLY the suggestion sentence.
`,
    });

    res.json({
      suggestion: response.output_text.trim(),
    });
  } catch (error) {
    console.error('HEY GIRL ERROR:', error);

    res.status(500).json({
      error: 'Pinori could not create an insight',
    });
  }
});

app.listen(PORT, () => {
  console.log(
    `Pinori backend running on http://localhost:${PORT}`
  );
});