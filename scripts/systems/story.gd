class_name Story
extends RefCounted
## All story and flavour text. Kept deliberately light: an intro card, signs,
## two recurring NPCs, boss lines, collectible jokes and an ending.
## The open questions in the Bible (why he was killed, what raised him) are
## answered here minimally; see docs/STORY.md.

const INTRO := [
	"Once, Jest the Fool could make the whole Court laugh.",
	"Then he told one joke about the King. The King did not laugh.",
	"They dropped him in the moat on a festival night, bells and all.",
	"A year later, under the same festival moon, something climbs out.",
	"A grin with no face behind it. A hammer far too big.",
	"He has one last joke to tell. The punchline is upstairs.",
]

const ENDING := [
	"The King's crown rolls across the throne room floor.",
	"For a moment nobody breathes. Then Princess Seraphine laughs.",
	"Then the guards. Then the nobles. Then the whole Court, together, at last.",
	"The King, at last, has heard the joke.",
	"The Fool bows. The bells on his hat ring once.",
	"And the curtain comes down on The Jester's Court.",
]

const AREA_SUBTITLES := {
	"carnival_gate": "Where the festival never ended",
	"outer_walls": "The long climb along the ramparts",
	"royal_gardens": "Something tolls among the roses",
	"grand_halls": "Mind your manners. Mind the porcelain.",
	"clockworks": "The castle's ticking heart",
	"throne_spire": "Where the punchline waits",
}

const SIGNS := {
	"intro": "THE JESTER'S COURT. Move with A and D. Jump with Space; hold it to jump higher.",
	"move": "Hit the guards with J. Hit them hard enough and they fly. Knock one into another!",
	"pogo": "In the air, hold S and press J to strike down. Bounce off foes, crates and even spikes.",
	"air_combo": "In the air, press J up to three times. Every hit bounces you higher: stay up, keep swinging.",
	"dash": "Press Shift to dash in any direction. Landing or hitting a foe in the air gives the dash back.",
	"chain": "Hold K to charge a heavy swing. Launch a foe into its friends for a chain.",
	"shrine": "Shrines heal you, save your progress and let you change charms. Press E to rest.",
}

const SPOOK := {
	"carnival_gate": [
		"Boo! Oh, it's you. Nobody's afraid of a ghost with a skull that friendly.",
		"The Ringmaster runs this festival now. He keeps the big top past the eastern stalls.",
		"See that chasm east of here? Nobody crosses that without floating like a leaf.",
	],
	"outer_walls": [
		"The walls go up, and up. The Executioner patrols the top. He never forgot your face.",
		"Walls too tall to climb? Plant that hammer and vault, if you knew how.",
	],
	"royal_gardens": [
		"Listen. The bell tolls on its own here. It tolls for everyone who ever laughed.",
		"Cracked stone everywhere in these gardens. One good wallop would open a lot of doors.",
	],
	"grand_halls": [
		"Mind the porcelain courtiers. They shatter, and so do their manners.",
		"The Acrobat Twins bounce off the walls. Watch them, and you might learn something.",
	],
	"clockworks": [
		"Tick, tock. The Colossus winds the whole castle. Stop it and the barriers fade.",
		"Those shimmering walls? Court magic. Only a step out of this world goes through.",
	],
	"throne_spire": [
		"Five seals, five fools beaten. The throne room is right up there.",
		"Whatever happens up there, Jest: make it funny.",
	],
}

const PIPPET := [
	"Pippet the page, at your service! Well, at the service of anyone with bells.",
	"Charms, charms, lovely charms! Rest at a shrine to wear them.",
	"I ran away from the castle kitchens. Don't tell the cook. He's a skeleton too now. Not like you.",
]

const BOSS_LINES := {
	"ringmaster": ["Ladies and gentlemen! The Fool returns!", "Let's see him jump through a hoop... of FIRE!"],
	"executioner": ["I took your head once, Fool.", "I will take it again."],
	"mourning_bell": ["(A low toll shakes the roses.)", "(It remembers every laugh. It wants yours.)"],
	"acrobat_twins": ["Two of us!", "One of you! Hup!"],
	"colossus": ["WINDING.", "WINDING. WINDING. INTRUDER."],
	"king": ["You. I had you drowned.", "Guards! Someone! Somebody stop that FOOL!"],
}

## Lost jokes: collectible pages from Jest's old joke book.
const JOKES := [
	"Why did the King's crown go to school? To get a little more brain under it.",
	"A knight walks into a bar. Clang.",
	"What do you call a skeleton who won't work? Lazy bones. Rude, I'm on a mission.",
	"The royal chef serves soup to the King. 'It's cold!' 'It's gazpacho, Majesty.' Off with his ladle.",
	"How many guards does it take to light a candle? None. They wait for the Fool to trip over it.",
	"I asked the moat for advice. It said 'glub.' Best advice I ever got.",
	"Why don't bats knight anyone? Their swords are all wing and no blade.",
	"The Executioner's favourite dance? The chop-chop shuffle.",
	"My hammer and I have a lot in common. We both hit things and nobody asks us why.",
	"What's a ghost's favourite fruit? Boo-berries. The Spook told me that one. It's his only one.",
	"Knock knock. Who's there? Hammer. Hammer who? Hammer-ican't hear you over all this smashing.",
	"The King once laughed at a joke. Historians are still arguing about which one.",
	"Why did the balloon page quit? Too much pressure.",
	"The Ringmaster said I'd never get top billing. Look at me now: top of the castle, billing him.",
	"What do clockwork knights eat for breakfast? Nuts and bolts. Hold the bolts.",
	"I'm not bitter about being drowned. I'm just a little wet behind the ears. Well, the ear holes.",
	"A porcelain lady told me to mind my manners. I minded her shins. They broke.",
	"Why do the gardens smell like roses? Because the King made it illegal to smell like anything else.",
	"How do you make a Bulwark laugh? Hit him from behind. He'll never see it coming. Neither will you.",
	"The Inquisitor asked if I had anything to confess. I said my jokes. He said guilty.",
	"What's the difference between a jester and a king? One wears bells, the other wears everyone out.",
	"I tried to tell the Colossus a joke. It took a while to wind up.",
	"Royal decree: all jokes must be approved by the King. Which is why nobody had laughed in years.",
	"Why did the arbalest miss? It was too cross to focus.",
	"I bounced off a guard's head. He said 'ow.' I said 'encore!'",
	"The Acrobat Twins never argue. They just flip about it.",
	"A skeleton walks into a tavern. Orders a pint and a mop.",
	"What do you call a hound made of clockwork? A watch dog.",
	"Princess Seraphine once snorted milk at one of my jokes. Treason, apparently.",
	"Never trust a staircase. It's always up to something.",
	"The Mourning Bell rings for every laugh it remembers. It must be exhausted.",
	"My mother always said I'd lose my head someday. She was half right. I kept the skull.",
	"Why are the castle walls so tall? To keep the punchlines in.",
	"What's a knight's least favourite hour? Night shift. Every hour is night shift. It's a castle.",
	"How does the King count his money? One for me, one for me, one for the Fool... no wait.",
	"The court wizard turned a frog into a prince. Then the prince into a tax collector. Sorcery has limits.",
	"Pippet asked why I carry a hammer. I said for the same reason you carry bells: to make noise.",
	"Spikes are just the floor's way of saying 'keep bouncing.'",
	"The secret to comedy is timing. The secret to dodging a mace is also timing. Same secret, really.",
	"If you laugh in the Grand Halls, the echo laughs back. It's the only friendly thing in there.",
	"Why did the King build a tower so tall? To look down on people more efficiently.",
	"This is the last page. The joke is: you read all of these. Thank you. Bow.",
]


static func joke_for(id: String) -> String:
	return JOKES[absi(hash(id)) % JOKES.size()]
