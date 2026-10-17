@tool
class_name Icons
extends RefCounted
## Hand-drawn 16x16 pixel icons for materials, tools and skills.
## k=outline m=main l=light d=dark w=wood h=wood light s=steel t=steel dark g=accent y=yellow e=dark eye r=red

const SHAPES := {
	"ore": ["................", "................", ".....kkkk.......", "....klllmkk.....", "...klllmmmmk....", "..kllmmmgmmkk...", "..klmmmmmmmmmk..", ".kllmmgmmmmmdmk.",
		".klmmmmmmmgmdmk.", ".kmmmgmmmmmdddk.", ".kmmmmmmmddddk..", "..kmmmmmddddk...", "...kkmddddkk....", ".....kkkkkk.....", "................", "................"],
	"bar": ["................", "................", "................", "................", "...kkkkkkkkkkk..", "..kllllllllllmk.", ".kllllllllllmmk.", ".kkkkkkkkkkkmmk.",
		".klmmmmmmmmkmdk.", ".klmmmmmmmmkddk.", ".kmmmmmmmmmkdk..", ".kmmmmmmmmdkk...", ".kddddddddkk....", "..kkkkkkkkk.....", "................", "................"],
	"log": ["................", "................", "................", "................", "....kkkkkkkkk...", "..kkhhhhhhhhwk..", ".kllkhwwwwwwwwk.", ".klmlkwwwwwwwdk.",
		".kmgmkwwwwwwddk.", ".klmlkwwwwwdddk.", "..kkkkwwwwdddk..", "......kkkkkkk...", "................", "................", "................", "................"],
	"herb": ["................", ".......kk.......", "......kllk......", ".....kllmmk.....", "..kk.kllmmk.kk..", ".kllkkmmmdkkllk.", ".kllmkkmdkkmmmk.", ".kmmmmkkdkmmmdk.",
		"..kmmdkwkkdddk..", "...kkkkwkkkkk...", "......kwk.......", "......kwk.......", "......kwk.......", ".....kwwk.......", "................", "................"],
	"bud": ["................", "......kkkk......", "....kkmmmmkk....", "...kmmllmmmmk...", "...kmlyyyymmk...", "...kmmyyyymdk...", "...kkmmmmddkk...", "....kkkddkkk....",
		"......kgk.......", "....kkkgk.......", "...kggkgkkk.....", "....kkkgkggk....", "......kgkkk.....", "......kgk.......", "......kgk.......", "................"],
	"root": ["................", "...k.......k....", "..kmk..k..kmk...", "..kmmk.mk.kmk...", "...kmmkmmkmmk...", "....kmmmmmmk....", "....kmlmmmdk....", ".....kmlmmdk....",
		".....kmmmdk.....", "....kmmmdkk.....", "....kmmdk.......", "...kmmdk........", "...kmdk.........", "...kdk..........", "....k...........", "................"],
	"crystal": ["................", ".......kk.......", "......klmk......", ".....kllmmk.....", ".....kllmdk.....", "..kk.kllmdk.kk..", ".klmkkllmdkklmk.", ".klmmkllmdkmmdk.",
		".kllmkmlmddkmdk.", ".kmmmmkmmdkdddk.", ".kkdddkmmdkkkk..", "...kkkkdddk.....", ".......kkk......", "................", "................", "................"],
	"gel": ["................", "................", "................", "......kkkk......", ".....kllllk.....", "....kllmmmmk....", "...kllmmmmmmk...", "..klmmmmmmmmmk..",
		"..kmmmmmmmmmdk..", ".kmmmmmmmmmmddk.", ".kmmmmmmmmmdddk.", ".kdmmmmmmddddk..", "..kkddddddkkk...", "....kkkkkk......", "................", "................"],
	"pelt": ["................", "..kk.....kk.....", ".kmmkkkkkkmmk...", ".kmmmmmmmmmmmk..", "kmmlmmmmmmmmmmk.", "kmlmmmmdmmmmdmk.", ".kmmmmmmmmmmmmk.", ".kmmmdmmmmlmmk..",
		"kmmmmmmmmmmmmmk.", ".kmdmmmmdmmmmk..", ".kmmmmmmmmmdmk..", "..kmmkmmmmkmmk..", "...kk.kmmk.kk...", "........kk......", "................", "................"],
	"fish": ["................", "................", "................", "....kkkkkkk.....", "..kkllllmmmkk..k", ".klllllmmmmmmkkk", "kllekmmmmmmmmmmk", "kllmkmmmmmmmmmmk",
		".kmmkmmmmmmmmkkk", "..kkmmddddmmkk.k", "....kkkkkkkk....", "................", "................", "................", "................", "................"],
	"cooked": ["................", "................", "................", "....kkkkkkk.....", "..kkllllmmmkk..k", ".klllldlmdmmmkkk", "kllekmdmmdmmmmmk", "kllmkmdmmdmmmmmk",
		".kmmkmdmmdmmmkkk", "..kkmmddddmmkk.k", "....kkkkkkkk....", "................", "................", "................", "................", "................"],
	"potion": ["................", "......kkkk......", "......kwwk......", ".......kk.......", "......kggk......", "......kggk......", ".....kllmmk.....", "....kllmmmmk....",
		"...kllmmmmmmk...", "...klmmmmmmdk...", "...kmmmmmmmdk...", "...kmmmmmmddk...", "....kmmmmddk....", ".....kkkkkk.....", "................", "................"],
	"vial": ["................", ".......kk.......", "......kwwk......", "......kggk......", "......kggk......", ".....kgllgk.....", "....kgllggdk....", "...kgllggggdk...",
		"...kglgggggdk...", "...kgggggggdk...", "...kgggggmmdk...", "....kggggmmk....", ".....kkkkkk.....", "................", "................", "................"],
	"pickaxe": ["................", "....kkkkkkk.....", "..kkmmllllmkk...", ".kmmmkkkkkkmmk..", ".kmk...kwk.kmk..", ".kk....kwk..kk..", ".......kwk......", ".......kwk......",
		"......kwhk......", "......kwk.......", ".....kwhk.......", ".....kwk........", "....kwhk........", "....kk..........", "................", "................"],
	"hammer": ["................", "..kkkkkkkkk.....", "..kmmmllllkk....", "..kmmmmmmmmk....", "..kmmmmmmmmk....", "..kkkkkwkkk.....", ".......kwk......", ".......kwk......",
		".......kwhk.....", "........kwk.....", "........kwhk....", ".........kwk....", ".........kk.....", "................", "................", "................"],
	"axe": ["................", ".....kkkk.......", "....kmmmmkk.....", "...kmllmmmmk....", "...kmlmmmmmmk...", "...kmmmmmmmmk...", "...kkmmmmmmk....", ".....kkkwkk.....",
		".......kwk......", ".......kwk......", "......kwhk......", "......kwk.......", ".....kwhk.......", ".....kk.........", "................", "................"],
	"rod": ["..............kk", ".............kwk", "............kwk.", "...........kwk..", "..........kwk...", ".........kwk.k..", "........kwk..k..", ".......kwk...k..",
		"......kwk....k..", ".....kwk.....k..", "....kwk......k..", "...kwk.......kgk", "..kwk.........kk", "..kk............", "................", "................"],
	"flintsteel": ["................", "................", "..kkkkkkk.......", ".ktssssstk......", ".kts...kstk.....", ".kts....kstk..y.", ".kts...kkstk.yry", ".ktssssk.kk...y.",
		"..kkkkk.kkkkk...", ".......kgggggk..", "......kgggggggk.", "......kgggdgggk.", ".......kddddk...", "........kkkk....", "................", "................"],
	"flint": ["................", "................", "................", "......kk........", ".....klmk.......", "....kllmmk.kk...", "...kllmmmmklmk..", "..kllmmmmmmmmk..",
		"..klmmmmmmmmdk..", "..kmmmmmmmmddk..", "...kmmmmmddkk...", "....kkddddk.....", "......kkkk......", "................", "................", "................"],
	"twig": ["................", ".............kk.", "............khk.", "..k........kwk..", "..kk......kwk...", "...kwk...kwk....", "....kwk.kwk.....", ".....kwkwk......",
		"......kwk.......", ".....kwkwk......", "....kwk.kwhk....", "...kwk...kwk....", "..khk.....kk....", "..kk............", "................", "................"],
	"grub": ["................", "................", "................", "................", "..kkkk.kkkk.....", ".kmlmmkmlmmkkk..", "kmmmmmdmmmmmmmk.", "kmdmmmdmdmmmmdek", ".kddmmkddmmmdk..",
		"..kkkk.kkkkkk...", "................", "................", "................", "................", "................", "................"],
	"kindling": ["................", "......kk........", ".....khk.kk.....", "....kwhk.khk....", "...kwhk..kwk....", "...kwk.kk.kk....", "..kwwkkwwkk.....", "..kkkgggggk.....",
		"..kwkgrrgkk.....", ".kwwkgggggkk....", ".kwk.kgggk......", ".kk...kkk.......", "................", "................", "................", "................"],
}

const SKILL_SHAPES := {
	"melee": ["................", "..kk.......kk...", ".kskk.....kkgk..", ".ktskk...kksk...", "..ktskk.kksk....", "...ktskkksk.....", "....ktsssk......", ".....ktsk.......",
		"....kwkskk......", "...kwk.ktsk.....", "..kwk...ktsk....", ".kgk.....kwk....", ".kk.......kk....", "................", "................", "................"],
	"magic": ["................", ".......kk.......", ".......kyk......", "......kyyyk.....", "..kkkkkyyykkkk..", ".kyyyyyyyyyyyyk.", "..kkkkkyyykkkk..", ".....kyyyyk.....",
		"....kyykkyyk....", "....kyk..kyk....", "...kyk....kyk...", "...kk......kk...", "................", "................", "................", "................"],
	"ranged": ["...........kkk..", "...........kssk.", "....kkk.....kssk", "...kwwwk.....kk.", "..kwk.kwk..kk...", ".kwk...kwkk.....", ".kwk...ksk......", ".kwkkkkwkkkkk...",
		".kwk...kwk..kk..", "..kwk.kwk....kk.", "...kwwwk.....kk.", "....kkk..kkkkk..", "................", "................", "................", "................"],
	"slayer": ["................", "....kkkkkkk.....", "...kllllllmk....", "..kllllllllmk...", "..klkkllkkmmk...", "..klkkllkkmmk...", "..kllllkllmmk...", "...kllkkkmmk....",
		"....kmmmmmk.....", "....kkmkmkk.....", ".....kkkkk......", "................", "................", "................", "................", "................"],
	"herblore": ["................", "......kkkk......", "......kwwk......", ".......kk.......", "......kggk......", ".....kgllgk.....", "....kgllmmgk....", "...kgllmmmmgk...",
		"...kgmmmmmmgk...", "...kgmmmmmmgk...", "...kgmmmmmdgk...", "....kgmmmdgk....", ".....kkkkkk.....", "................", "................", "................"],
	"smithing": ["................", "................", ".kkkkkkkkkkkk...", ".ktssssssssstkk.", "..ktssssssssstk.", "...kkttsssstkk..", ".....kttssstk...", "......ktsstk....",
		"......ktsstk....", ".....kttsssstk..", "....kttttttttk..", "....kkkkkkkkkk..", "................", "................", "................", "................"],
	"crafting": ["................", "..........kk....", ".........ksk....", "........ksk.....", ".......ksk......", "......ksk.......", ".....kwk........", "....kwk.kk......",
		"...kwk.kskk.....", "..kwk..kssk.....", ".kgk...kssk.....", "..k.....kk......", "................", "................", "................", "................"],
	"cooking": ["................", ".....y..y.......", "....yry.yr......", "....yrrykyr.....", ".....kykrrk.....", "....kkrrrykk....", "...kryyyyrrk....", "...kryyyyyrk....",
		"....kkryykk.....", ".....kkkkk......", "................", "................", "................", "................", "................", "................"],
	"firemaking": ["................", ".......k........", "......kyk.......", "......kyyk......", ".....kyyyk.k....", "....kyyryyky....", "....kyrrrykyk...", "...kyyrrrrykk...",
		"...kyrrrrryyk...", "...kyrrrrrryk...", "....kyrrrryk....", ".....kkkkkk.....", "..kwwwkkkkwwwk..", "...kkwwwwwwkk...", "....kkkkkkkk....", "................"],
	"agility": ["................", "................", "......kkkk......", ".....kmmmmk.....", ".....kmmmmk.....", "......kkkk......", "...kk.kmmk.kk...", "..kmmkmmmmkmmk..",
		"...kmmmmmmmmk...", "....kkmmmmkk....", ".....kmkkmk.....", "....kmk..kmk....", "...kmk....kmk...", "..kkk......kkk..", "................", "................"],
	"mining": [],
	"woodcutting": [],
	"fishing": [],
}

const ABILITY_SHAPES := {
	"backstab": ["....kkkk........", "...kwwwwk.......", "....kwhk........", "..kttttttk......", "....kssk........", "....kssk........", "....kssk........", "....ksstk.......", "....kstk........", "...kkstkk.......", ".kk.kktk.kk.....", "kRrk.kk.krRk....", ".kRrrrrrrRk.....", "..kkRRRRkk......", "....kkkk........", "................"],
	"step": ["................", "......kkk.......", ".....kpppk......", "kkkkkkkppWk.....", "PPppppppppWk....", "kkkkkkkkkpWWk...", "kkkkkkkkkkpWWk..", "PPPPPpppppppWpk.", "kkkkkkkkkkkkpWpk", "kkkkkkkkk.kpWpk.", "PPPppppppkpWWk..", "kkkkkkkkkpWWk...", ".......kppWk....", "......kppWk.....", ".....kpppk......", "......kkk......."],
	"stealth": ["................", "......kkkkkk....", ".....kPPPPPPk...", "....kPPPPPPPPk..", "...kPPkkkkkkPPk.", "...kPPkyykyykPk.", "...kPPkyykyykPk.", "...kPPPkkkkkPPk.", "....kPPPPPPPPk..", "...kPPPPPPPPPPk.", "..kPPPPkPPkPPPPk", "..kkkkkkkkkkkkkk", "................", "................", "................", "................"],
	"poison": ["...........kkk..", "..........kwwk..", ".........kwhk...", "........kttk....", "......kkttkk....", "....kkssk.......", "...kssk.k.......", "..kssk..........", "..kstk.G........", ".kkkk..gG.......", "..k....gg.......", "......kGgk......", "......kGGk......", ".......kk.......", "................", "................"],
	"fan": ["................", ".......kk.......", "......kssk......", "......kssk......", "......kssk......", "kk....kssk....kk", "ssk...kssk...kss", "ksk...kssk...ksk", ".ksk..kssk..ksk.", "..ksk.kssk.ksk..", "...kskksskksk...", "....kskswksk....", "....kwwswwwk....", ".....kwwwwk.....", "......kwwk......", ".......kk......."],
	"smoke": ["................", "......kkkk......", "....kkooookk....", "...kooWWooook...", "..kooWoooooOk...", ".kkooooooooOkk..", "kooooooooooOOok.", "koooWoooooooOOk.", "kkooooooooOOOkk.", ".kkOOooooOOOkk..", "..kkOOOOOOOkk...", "....kkkkkkk.....", "................", "................", "................", "................"],
	"flurry": [".........kyk....", "........kyWk....", ".......kyWyk....", "......kyWWk.k...", "......kyWykkyk..", ".....kyWykkyWk..", "....kyWWkyWWyk..", "....kWWykWWykkk.", "...kyWykyWykkyWk", "..kyWykyWykkyWWk", "..kWWyyWykkyWyyk", ".kyWyyWWkyWWykk.", ".kWyyWWyyWWyk...", "..kkWWyyWWyk....", "...kWyyWWyk.....", "....kkWykk......"],
	"assassinate": ["......kkkk......", "....kkrrrrkk....", "...krrkkkkrrk...", "..krkk.kk.kkrk..", "..krk..kk..krk..", ".kkkkkkttkkkkkk.", "kRrrrrrstrrrrrRk", ".kkkkkkttkkkkk..", "..krk..ks..krk..", "..krkk.ks.kkrk..", "...krrkkskrrk...", "....kkrrrrkk....", "......kkkk......", "................", "................", "................"],
	"venomburst": ["......kggk......", "......kggk......", "...k..kggk..k...", "..kgk.kggk.kgk..", "...kgkkggkkgk...", "....kGGGGGGk....", "kkkkkGggggGkkkkk", "gggggGgyygGGgggg", "gggggGgyygGGgggg", "kkkkkGggggGkkkkk", "....kGGGGGGk....", "...kgkkGGkkgk...", "..kgk.kggk.kgk..", "...k..kggk..k...", "......kggk......", "......kggk......"],
	"strike": ["...........k.k..", "..........kykyk.", "...........kyk..", "...........kkyk.", "..........kstkyk", ".........kstk.k.", "........kstk....", ".......kstk.....", "......kstk......", "..k..kstk.......", ".kykkstk........", "..kwstk.........", ".kwsyk..........", "kwwkkyk.........", "kwk..k..........", ".k.............."],
	"charge": ["................", "................", "..kk...kk.......", ".kRRk.krrk......", "..kRRk.krrk.....", ".kkkRRk.krrk....", "kyyykRRk.krrk...", "kkkk.kRRk.krrk..", "yyyk..kRRk.krrk.", "kkkk.kRRk.krrk..", "kyyykRRk.krrk...", ".kkkRRk.krrk....", "..kRRk.krrk.....", ".kRRk.krrk......", "..kk...kk.......", "................"],
	"cleave": ["................", "....kk..........", "..kkyyk..kkkkk..", ".kyyyk..kWWWWWk.", "kyykk...kssssstk", ".kkyk...kssssstk", "kyyk....kwsssstk", "ykk....kwhsssstk", "k......kwhtttttk", "......kwhkkkkkk.", "......kwhk......", ".....kwhk.......", "....kwhhk.......", "....kwhk........", "...kwhk.........", "....kk.........."],
	"whirl": ["................", "......kkkk......", "....kkssssk.....", "...ksssttssk....", "..kssttkksssk...", "..kstkk.ksssk...", ".ksstk.kkkkk....", ".kstk.kyyk..kk..", ".kstk.kyyk.ktsk.", "..kkkkkkk.ktssk.", "...ksssk.kktsk..", "...kssskkttssk..", "....kssttsssk...", ".....ksssskk....", "......kkkk......", "................"],
	"shout": ["................", "................", "..........k.....", ".........kck..k.", "........kcyk.krk", "..kkkkkkcyykkrk.", ".knnnnycyyyk.krk", ".knnnnyyyyykkrrk", ".knnnnyyyyyk.krk", ".knnnnyyyyykkrrk", "..kkkkkkyyyk.kk.", "........kyykkrk.", ".........kyk.krk", "..........k...k.", "................", "................"],
	"slam": [".....kkkkkk.....", "....knnnnnnk....", "....knnnnnnk....", "....kRrrrrrk....", "....krrrrrrk....", "....krrrrrrk....", "...kkrrrrrrkk...", "..kokrRRRRrkok..", ".kok.kRRRRk.kok.", "kOk.kkRRRRkk.kOk", ".kkkOkkkkkkOkkk.", "kkkkkkkkkkkkkkkk", "hhkkhhhhhhhhkkhh", "wwwwwwwwwwwwwwww", "wwwwwwwwwwwwwwww", "kkkkkkkkkkkkkkkk"],
	"stand": ["................", "...kkkkkkkkkk...", "..kWWWWWWWWWWk..", "..ksssssssssk...", "..kssrrrrrssk...", "..kssrryyrssk...", "..kssrryyrssk...", "..kssrryyrssk...", "..kssrrrrrrssk..", "...kssrrrrssk...", "....kssrrssk....", ".....kssssk.....", ".....kssssk.....", "......kssk......", ".......kk.......", "................"],
	"fireball": ["................", "............k...", ".......kkkkknk..", "......knnnnnk...", ".....knnyyynnk..", "....knnyccyynk..", "....knnyccyynnk.", "....knnyccyynnk.", "....kknyyyyynk..", "..kknnnnyyynnk..", ".knnkNnnnnnnk...", "knkkNnnkkkkkNk..", ".kkNnnk.....k...", ".kNknk..........", "..knk...........", "...k............"],
	"blink": ["................", "................", "..........k.....", ".........kpk....", ".........kpk....", "kkk......kpk....", "PPPk....kpWpk...", "kkkk.kkkppWppkkk", ".kPPkpppWWWWWppp", "kkkk.kkkppWppkkk", "PPPk....kpWpk...", "kkk.....kpppk...", ".........kpk....", ".........kpk....", "..........k.....", "................"],
	"nova": [".......k........", "......kbk.......", "...k..kbk...k...", "..kBk.kbk..kBk..", "...kBkkWk.kBk...", "....kBkkbkBk....", ".....kBWWBk.....", ".kkkkkWWWWkkkkk.", "kbbbWbWWWWbbWbbk", ".kkkkkBWWBkkkkk.", "....kBkkbkBk....", "...kBk.kbkkBk...", "..kBk..kWk.kBk..", "...k...kbk..k...", ".......kbk......", "........k......."],
	"barrier": ["................", "................", "......kkkk......", "....kkPPPPk.....", "...kPPPPPPPk....", "...kPPWppPPPk...", "...kPWWpWpPPk...", "..kPPWpWpWpPPk..", ".kPPPpppWppPPk..", ".kPPpppppppPPk..", ".kPPpppppppPPk..", ".kPPpppppppPPk..", "..kPPPPPPPPPPk..", ".kPPPPPPPPPPPPk.", "..kkkkkkkkkkkk..", "................"],
	"chain": ["..kk.........k..", ".kcck.......kck.", "kcWcck.....kWcck", "kcccck....kkccck", ".kccyyk..kyycck.", "..kkkyykkycckk..", ".....kyyyckk....", ".....kyyyk......", "....kyykk.......", ".....kyyyk......", "......kyyykk....", ".......kyyyck...", "........kkWcck..", ".........kccck..", "..........kck...", "...........k...."],
	"meteor": ["............knkN", "...........knkNk", "..........knkNkn", ".........knkNknk", ".....kkkknkNknk.", "...kkmmmnkNknk..", "..kmOOOOmmknk...", "..kOOoOOOmnk....", ".kmOoooOOmmk....", ".kmOOoOOOnmk....", ".kmOOOOONmmk....", "..kmOOOOmmk.....", ".kNmmmmnmmk.....", "..kkkmmmkk......", ".....kkk........", "................"],
	"power": ["................", "............kkk.", "...........ktWsk", "..........ktWssk", "..........kWsstt", ".......k.ktttssk", "......kykssssssk", ".....kykwhkkkkk.", "....kyywhk......", "....kywhk.......", ".k.kywhk........", "krkkwhk.........", ".krwhk..........", "kkwhk...........", "ywhrk...........", "kkyk............"],
	"disengage": ["................", "................", "........kkkk....", "...k...kwwwwk...", "..kgk..kwwwwk...", ".kgkkkkkhhhhk...", "kggggggkhhhhk...", ".kgkkkkkhhhhk...", ".kGGGk.khhhhk...", ".kkkkk.khhhhkkk.", "kGGGGGkkwwwwwwwk", ".kkkkk.kwwwwwwwk", ".......kwwwwwwwk", ".......kkkkkkkkk", "........kkkkkkk.", "................"],
	"volley": [".k............k.", "ksk..........ksk", "ksk....kk....ksk", "khhk..kssk..khhk", ".khk...khk..khk.", ".khhk..khk.khhk.", "..khk..khk.khk..", "...khk.khkkhhk..", "...khk.khkkhk...", "....khkkhkhk....", "....khkkhkhk....", ".....khkhhk.....", ".....khkhhk.....", "......khhk......", "......kwwk......", ".....krkkrk....."],
	"trap": ["................", "................", "...........k....", "....k.....kok...", "...kok....kok.k.", "...kok..k.kokkok", "..kkookkokookkk.", ".koooookooooook.", ".koooookroooook.", ".koooookooooook.", ".kOOOOOkoOOOOOk.", ".kooooooooooook.", ".kOOOOttttOOOOk.", "..kkkkttttkkkk..", ".....kttttk.....", "......kkkk......"],
	"rain": ["........kkk.....", "....kkkkoook....", "...kOOOoooook...", "..kOOOOoooooOk..", "..kOOOOooooOOOk.", "..koooooooooooOk", "..ksooooooosook.", "..kskkkkkkksOk..", "..khhkksk.khhk..", "..khk.ksk.khk...", "..khk.khhkkhk...", "..khk.khk.khk...", ".khhk.khkkhhk...", ".krrk.khkkrrk...", "..kk.krrk.kk....", "......kk........"],
	"wolf": ["................", "................", "..k..........k..", ".kBk........kBk.", ".kBBkkkkkkkkbBk.", ".kBBbBBBBBBbbBk.", ".kBBbbbbbbbbbBk.", ".kBBbbbbbbbbbBk.", ".kBBbkkbbkkbbBBk", "..kBbbbWWbbbbBk.", "...kBbbkkbbbBk..", "...kBbbkkbbbBk..", "....kBWbbWbBk...", "....kBBBbBBBk...", ".....kkBBBkk....", ".......kkk......"],
}

const TALENT_SHAPES := {
	"dagger": ["................", "................", "............kk..", "...........kssk.", "..........kssk..", ".........kssk...", "........kssk....", ".......kssk.....", "...kk.kssk......", "..kaakssk.......", "...kaask........", "...kwaak........", "..kwkkak........", ".kAk..k.........", "..k.............", "................"],
	"crossblades": ["................", "................", "...kk.......kk..", "..kssk.....kssk.", "...kssk...kssk..", "....kssk.kssk...", ".....ksskssk....", "......ksssk.....", "......ksssk.....", "..kk.kssksskkk..", ".kaakssk.kssaak.", "..kaask...kaak..", "..kwaak..kaawsk.", ".kwkkak..kakkwk.", "kAk..k....k..kAk", ".k............k."],
	"crosshair": [".......kak......", ".....kkkakk.....", "....kaaaaaak....", "...kaaakaaaak...", "..kaakkkakkaak..", ".kaak...k..kaak.", ".kaak..kk..kaak.", "kkakk.kWWk.kkakk", "aaaaakkWWkkaaaaa", "kkaak..kk..kaakk", ".kaak...k..kaak.", "..kaakkkakkaak..", "...kaaakaaaak...", "....kaaaaaak....", ".....kkkakk.....", ".......kak......"],
	"target": ["................", "......kkkk......", "....kkWWWWkk....", "...kWWWaaWWWk...", "..kWWaaaaaaWWk..", "..kWaaWWWWaaWk..", ".kWWaWWrrWWaWWk.", ".kWaaWrrrrWaaWk.", ".kWaaWrrrrWaaWk.", ".kWWaWWrrWWaWWk.", "..kWaaWWWWaaWk..", "..kWWaaaaaaWWk..", "...kWWWaaWWWk...", "....kkWWWWkk....", "......kkkk......", "................"],
	"boot": ["................", "....kkkkk.......", "...koooook......", "...koooook......", "...koWWWWk......", "...koooook......", "...koooook......", "...koooook......", "...kooooookk....", "...kooooooook...", "...koooooooook..", "...kaaaaaaaaak..", "...kaaaaaaaaak..", "....kkkkkkkkk...", "................", "................"],
	"heart": ["..krrrrkkrrrrk..", ".krrrrrrrrrrrrk.", "krrrrrrrrrrrrrrk", "krrrrrrrrrrrrrrk", "krrrrWrrrrrrrrrk", "krrrWrrrrrrrrrrk", "krrrWrrrrrrrrrrk", ".krrrrrrrrrrrrk.", ".krrrrrrrrrrrrk.", "..krrrrrrrrrrk..", "...krrrrrrrrk...", "....krrrrrrk....", ".....kkrrkk.....", ".......kk.......", "................", "................"],
	"heart_drop": ["..kkkkkkkkkk....", ".krrrrrrrrrrk...", ".krrrrrrrrrrk...", "krrrWrrrrrrrrk..", "krrWrrrrrrrrrk..", "krrrrrrrrrrrrk..", ".krrrrrrrrrrk...", ".krrrrrrrrrrk...", "..krrrrrrrrk....", "...krrrrrraak...", "....krrrraaaak..", ".....kkkkaaAaak.", "........kaaaak..", ".........kaak...", "..........kk....", "................"],
	"shield": ["................", "...kkkkkkkkk....", "..ksssssssssk...", "..ksssssssssk...", "..kssaaaAassk...", "..kssaaaAassk...", "..kssaaaAassk...", "..kssaaaAassk...", "..kssaaaAassk...", "..ksssaaAsssk...", "...ksssaAssk....", "....ksssAsk.....", ".....ksssk......", "......ksk.......", ".......k........", "................"],
	"hourglass": ["................", "...kkkkkkkkk....", "..ksssssssssk...", "...kyyyyyysk....", "....kyyyyyk.....", "....ksyyysk.....", ".....ksysk......", ".....kssk.......", ".....ksssk......", "....kssyssk.....", "....ksyyysk.....", "...ksssssssk....", "..ksssssssssk...", "...kkkkkkkkk....", "................", "................"],
	"swirl": ["................", "................", "................", "......kkkkkk....", ".....kaaaaaak...", "....kaaakkaaak..", "....kaak..kaaak.", ".kk.kaakkk.kaak.", "kaakkaakaakkaak.", "kaak.kaaaakkaak.", ".kaak.kkkk.kaak.", ".kaaak....kaak..", "..kaaakkkkaak...", "...kkaaaaaak....", ".....kkkkkk.....", "................"],
	"clock": ["................", "......kkkk......", "....kkooookk....", "...koooWWoook...", "..kooWWWkWWook..", "..koWWWWkWWWok..", ".kooWWWWkWWWook.", ".koWWWWrkWWWWok.", ".koWWWWWkkWWWok.", ".kooWWWWWWkWook.", "..koWWWWWWWWok..", "..kooWWWWWWook..", "...koooWWoook...", "....kkooookk....", "......kkkk......", "................"],
	"bolt": ["................", "........k.......", ".......kyk......", "......kyyk......", ".....kyyyk......", ".....kyyykkkk...", "....kyyyyyyyyk..", "...kyyyyyyyyk...", "..kyyyyyyyyk....", "...kkkkyyyk.....", ".....kyyyk......", ".....kyyk.......", ".....kyk........", "....kyk.........", ".....k..........", "................"],
	"burst": [".......k........", "......kyk.......", "...k..kyk..k....", "..kykkkykkkyk...", "...kyyyyyyyk....", "...kyyyyyyyk....", ".kkkyyrrrrykkk..", "kyyyyyrrrryyyyk.", ".kkkyyrrrrykkk..", "...kyyrrrryk....", "...kyyyyyyyk....", "..kykkkykkkyk...", "...k..kyk..k....", "......kyk.......", ".......k........", "................"],
	"skull": ["................", ".....kkkkkk.....", "....kWWWWWWk....", "...kWWWWWWWWk...", "..kWWWWWWWWWWk..", "..kWWWWWWWWWWk..", "..kWWkkWWkkWWk..", "..kWWkkWWkkWWk..", "..kWWWWWWWWWWk..", "...kWWWkkWWWk...", "...kWWWWWWWk....", "...kWWWWWWk.....", "...kWkWkWkk.....", "....kkkkkk......", "................", "................"],
	"horn_skull": [".kkk.......kkk..", "kyyykkkkkkkyyyk.", ".kyykWWWWWyyyk..", "..kyyWWWWWyyk...", "..kWWWWWWWWWWk..", "..kWWWWWWWWWWk..", "..kWWkkWWkkWWk..", "..kWWkkWWkkWWk..", "..kWWWWWWWWWWk..", "...kWWWkkWWWk...", "...kWWWWWWWk....", "...kWWWWWWk.....", "...kWkWkWkk.....", "....kkkkkk......", "................", "................"],
	"drop": ["................", ".......k........", "......kak.......", ".....kaaak......", "....kaaaak......", "....kaaaaak.....", "...kaaaaaaak....", "..kaaaaaaaak....", "..kaaAaaaaaak...", "..kaaAaaaaaak...", "..kaaaaaaaaak...", "...kaaaaaaaak...", "...kaaaaaaaak...", "....kaaaaaak....", ".....kkkkkk.....", "................"],
	"drops": ["................", "................", "..........kk....", ".........kaak...", "....kk...kaak...", "...kaak.kaaaak..", "...kaakkaaaaaak.", "..kaaaakaaAaaak.", ".kaaaaaaaaaaaak.", ".kaaAaaakaaaaak.", ".kaaaaaakaaaaak.", "..kaaaaakkaaak..", "..kaaaaak.kkk...", "...kaaak........", "....kkk.........", "................"],
	"cloud": ["................", "................", "........kkk.....", "......kkoookk...", ".....koooooook..", "....kkooWooook..", "...koooWoooook..", "..koooooooooook.", ".koooooooooooook", ".koooooooooooook", ".koooooooooooook", "..kooooooooooook", "...koookkkooook.", "....kkk...kkkk..", "................", "................"],
	"spread": [".........k......", ".......kkokk....", "....kkkoooook...", "...koooooooook..", "..kooooooooook..", ".kooooooooooook.", ".koooooooooooook", ".koooooooooooook", "..koooooooooook.", "...kaookkkkaok..", "...kakkkk.kak...", "..kaaakaakaaak..", "..kaaaaaaaaaaak.", "..kaaaaaaaaaaak.", "...kaakaaakaak..", "....kk.kkk.kk..."],
	"wound": ["................", ".....kk.........", "....kaak........", "...kaaaak.......", "...kaaaak.......", "..kaaaaaak.kk...", ".kaaaaaaaakrrk..", "..kaaaaaaakkrrk.", "..kaaaaaarrkrrrk", "...kaaaaakrrkrrr", "....kaarrkkrrkrr", ".....kkkrrkrrrkr", ".......krrrkrrkk", "........krrrkrrk", ".........krrkkrr", "..........krrkkk"],
	"snail": ["................", ".......kkkkk....", "......kaaaaak...", ".....kaaaBaaak..", ".k..kaaBBBBBaak.", "kokkoaBBaBaBBak.", "kookoaBaBaBaBak.", ".kokoaBaBaBaBak.", "kooooaBBaBaBBak.", "kooooooooooBaak.", "oooooooooooaak..", "kooooooooooak...", "kooooooooook....", ".kkkkkkkkkk.....", "................", "................"],
	"eye": ["................", ".....kkkkkk.....", "....kWWWWWWk....", "...kWWWWWWWWk...", "..kWWWWaaWWWWk..", ".kWWWaaaaaaWWWk.", ".kWWWaWkkaaWWWk.", ".kWWaakkkkaaWWk.", ".kWWaakkkkaaWWk.", ".kWWWaakkaaWWWk.", ".kWWWaaaaaaWWWk.", "..kWWWWaaWWWWk..", "...kWWWWWWWWk...", "....kWWWWWWk....", ".....kkkkkk.....", "................"],
	"mask": ["................", ".....kkkkkk.....", "....kWWWaWWk....", "...kWWWWaWWWk...", "..kWWWWWaWWWWk..", ".kWWWWWWaWWWWWk.", ".kkWWWWWaWWWkWk.", ".kkkkkWWakkkkWk.", ".kkWWWWWaWWWkWk.", ".kWWWWWWaWWWWWk.", ".kWWWWWWaWWWWWk.", "..kWWWWWaWWWWk..", "...kWkkkkkkWk...", "....kWWWaWWk....", ".....kkkkkk.....", "................"],
	"hood": ["................", ".....kkkkkk.....", "....kaaaaaak....", "...kaaaaaaaak...", "..kaaaaaaaaaak..", ".kaaaakkkkaaaak.", ".kaaakkkkkkaaak.", ".kaaakkkkkkaaak.", ".kaakkWkkWkkaak.", ".kaaakkkkkkaaak.", ".kaaakkkkkkaak..", "kaaaaakkkkaaaak.", "kaaaaaaaaaaaaak.", "kaaaaaaaaaaaaak.", ".kkkkkkkkkkkkk..", "................"],
	"fist": ["................", "................", "................", "................", "...kkkkkkkkkk...", "..kAABABABABAk..", "..kABABABABAAk..", "..kaBaBaBaBaak..", ".kaaBaBaBaBaak..", ".kAaaaaaaaaaak..", ".kaaaaaaaaaaak..", ".kaaBBBBBBBBak..", "..kkBBBBBBBBk...", "...kBBBBBBBBk...", "....kkkkkkkk....", "................"],
	"flame": ["................", "........k.......", ".......kak......", ".......kaak.....", ".......kaak.....", ".......kaaak....", ".....k.kaaak....", "....kakkAaaak...", "....kaaaAAaak...", "...kaaaAAAaaak..", "..kaaaAAWAAaaak.", "...kaAAAWAAAak..", "...kaaAAWAAaak..", "....kaAAAAaak...", ".....kkkkkkk....", "................"],
	"snow": ["........k.......", ".......kak......", "......kkak......", "..k.kkAkaAkk.k..", ".kakAkkkakkAkak.", ".kaaak.kakkaaak.", "..kAaakkakaaAk..", "...kkkaWWakkk...", "...kkkaWWakkk...", "..kAaakkakaaAk..", ".kaaak.kakkaaak.", ".kakAkkkakkAkak.", "..k.kkAkaAkk.k..", "......kkak......", ".......kak......", "........k......."],
	"star": ["........k.......", ".......kak......", ".......kak......", ".......kak......", "......kaaak.....", "......kaAak.....", "....kkkaAakkk...", ".kkkaaaWAaaaakkk", "kaaaAAAAWAAAAaaa", ".kkkaaaAAAaaakkk", "....kkkaAakkk...", "......kaAak.....", "......kaaak.....", ".......kak......", ".......kak......", ".......kak......"],
	"arrow": ["..........kkkkk.", ".........ksssssk", "..........kWWWWk", "...........ksssk", "..........kwassk", ".........kwakksk", "........kwak..k.", ".......kwak.....", "......kwak......", ".....kwak.......", "..k.kwak........", ".kAkwak.........", "kAkwak..........", ".kAaAk..........", "..kAk...........", "...k............"],
	"paw": ["................", "................", ".....kk...kk....", "....kAak.kAak...", "....kaak.kaak...", "..kk.kk...kk.kk.", ".kAak.......kAak", ".kaak.kkkk..kaak", "..kk.kaaaak..kk.", "....kkaaaaak....", "...kaaaAAaaak...", "...kaaaaAaaak...", "...kaaaaaaaak...", "...kaaaaaaaaak..", "....kkkkkkkkk...", "................"],
	"leaf": ["................", "................", "......kkkkkkkk..", ".....kaaaaaaaak.", ".....kaAaaaaBak.", "....kAaaaaaBaak.", "..kkAaBaaaBaaak.", ".kaaaaBaaBaaaak.", ".kaaaaBaBBBBBak.", ".kaaaaBBaaaaaaak", ".kaaaaBaaaaaaak.", ".kaaaBaaaaaaak..", ".kaaBaaaaaaak...", ".kaBaaaaaaak....", "..kkkkkkkkk.....", "................"],
	"wing": ["..............k.", ".......kkkkkkkak", "......kaaaaaaak.", ".....kaaaaaAak..", "...kkaaAAAAak...", "..kaaaAAAaakkkk.", "..kaAAAAAAAAaaak", "..kaAAAAAAaaakk.", "..kaAAAAAakkk...", ".kaaAAaaaaakk...", ".kaaaaaaaaaaak..", "kaaaaaaakkkkk...", ".kaaaaaak.......", "..kaaaaak.......", "...kkkkk........", "................"],
	"gem": ["................", "................", ".....kkkkkkk....", "....kWWWWWWWk...", "....kAWWWWWAk...", "...kAAAWWWAAAk..", "..kAAAAAWAAAAAk.", ".kBBBBBBBBBBBBBk", "..kaaaaaaaaaaak.", "...kaaaaaaaaak..", "....kaaaaaaak...", ".....kaaaaak....", "......kaaak.....", ".......kak......", "........k.......", "................"],
}
## Passive talent id -> glyph in TALENT_SHAPES (tinted by the tree: sh_ shadow purple, ve_ venom green).
## Passive talent tint by the tree its id starts with.
const TREE_TINT := {"bw": "e8864a", "sh": "b49aff", "ve": "7ad84a", "py": "ff7a3a", "fr": "6ac8f0", "ar": "b080ff", "ma": "f0cc4a", "su": "7ad84a", "be": "e8864a"}
const TALENT_GLYPH := {
	"sh_ambush": "dagger",
	"sh_keen": "crosshair",
	"sh_nimble": "boot",
	"sh_hard": "heart",
	"sh_prep": "hourglass",
	"sh_evasion": "swirl",
	"sh_edge": "crossblades",
	"sh_deep": "hood",
	"sh_quick": "clock",
	"sh_adren": "bolt",
	"sh_lethal": "burst",
	"sh_exec": "skull",
	"sh_drink": "heart_drop",
	"sh_thick": "shield",
	"sh_opp": "eye",
	"sh_dance": "mask",
	"sh_cloak": "hood",
	"sh_marked": "target",
	"ve_potent": "drop",
	"ve_agile": "boot",
	"ve_resil": "heart",
	"ve_lasting": "hourglass",
	"ve_veil": "cloud",
	"ve_keen": "crosshair",
	"ve_quick": "clock",
	"ve_fester": "wound",
	"ve_flow": "bolt",
	"ve_dodge": "swirl",
	"ve_cripple": "snail",
	"ve_deadly": "skull",
	"ve_feast": "heart_drop",
	"ve_thick": "shield",
	"ve_contagion": "spread",
	"ve_dose": "drops",
	"ve_sharp": "dagger",
	"ve_marked": "horn_skull",
	"bw_thick": "shield",
	"bw_vital": "heart",
	"bw_stalwart": "shield",
	"bw_heavy": "fist",
	"bw_rally": "bolt",
	"bw_second": "heart_drop",
	"bw_quick": "clock",
	"bw_blood": "drop",
	"bw_crit": "crossblades",
	"bw_exec": "skull",
	"bw_unbreak": "shield",
	"bw_titan": "fist",
	"bw_marked": "horn_skull",
	"bw_vigor": "bolt",
	"bw_heroic": "dagger",
	"sh_backstab": "dagger",
	"sh_dual": "crossblades",
	"sh_sinister": "mask",
	"py_kindling": "flame",
	"py_searingfoc": "crosshair",
	"py_emberheart": "heart",
	"py_spellward": "shield",
	"py_firemaster": "flame",
	"py_hotstreak": "bolt",
	"py_cinderskin": "shield",
	"py_quickcast": "clock",
	"py_inferno": "burst",
	"py_criticalma": "target",
	"py_phoenixblo": "heart_drop",
	"fr_icyveins": "snow",
	"fr_chilltouch": "snow",
	"fr_wintervigo": "heart",
	"fr_glacialwar": "shield",
	"fr_shatter": "gem",
	"fr_frozencore": "gem",
	"fr_permafrost": "heart",
	"fr_deepfreeze": "snow",
	"fr_icewalker": "boot",
	"fr_absoluteze": "snow",
	"ar_arcanemind": "star",
	"ar_manasurge": "drop",
	"ar_magearmor": "shield",
	"ar_deepwell": "drops",
	"ar_quickening": "clock",
	"ar_phasestep": "swirl",
	"ar_overflow": "drops",
	"ar_arcanepowe": "star",
	"ar_timewarp": "hourglass",
	"ar_spellcrit": "target",
	"ma_steadyaim": "crosshair",
	"ma_quiverrese": "arrow",
	"ma_lightleath": "shield",
	"ma_deadeye": "eye",
	"ma_calledshot": "target",
	"ma_rapidfire": "arrow",
	"ma_fleetfoot": "boot",
	"ma_sniper": "crosshair",
	"ma_lethalaim": "target",
	"ma_bullseye": "target",
	"su_camouflage": "hood",
	"su_forager": "leaf",
	"su_trailblaze": "boot",
	"su_thickhide": "shield",
	"su_trapmaster": "clock",
	"su_fleet": "wing",
	"su_survivalis": "heart",
	"su_ambusher": "mask",
	"su_evasion": "swirl",
	"su_wildswalke": "wing",
	"be_packbond": "paw",
	"be_wildvigor": "heart",
	"be_huntersmar": "target",
	"be_swiftstrid": "wing",
	"be_alpha": "paw",
	"be_thickfur": "shield",
	"be_predator": "eye",
	"be_callofthew": "horn_skull",
	"be_apex": "paw",
	"be_ferocity": "burst",
	"be_spiritlink": "heart_drop",
}

## material id -> [shape, accent colour or ""]
const MAT_SHAPE := {
	"copper": "ore", "bogiron": "ore", "flint": "flint", "mossgel": "gel", "heartwood": "log", "oak": "log", "pelt": "pelt", "witchroot": "root", "marshroot": "root",
	"frost": "crystal", "rime": "crystal", "ember": "crystal", "frostbloom": "bud", "thornbud": "bud", "greenleaf": "herb",
	"raw_minnow": "fish", "raw_trout": "fish", "raw_eel": "fish", "raw_icefin": "fish",
	"minnow": "cooked", "trout": "cooked", "eel": "cooked", "icefin": "cooked",
	"hpot": "potion", "might": "potion", "swift": "potion", "greater": "potion", "vial": "vial",
	"wooden_pickaxe": "pickaxe", "pickaxe": "pickaxe", "bogiron_pickaxe": "pickaxe", "frost_pickaxe": "pickaxe",
	"wooden_axe": "axe", "axe": "axe", "bogiron_axe": "axe", "frost_axe": "axe", "rod": "rod", "flint_steel": "flintsteel", "hammer": "hammer",
	"twig": "twig", "bait_0": "grub", "bait_1": "grub", "bait_2": "grub", "bait_3": "grub",
	"copper_bar": "bar", "bogiron_bar": "bar", "frost_bar": "bar", "kindling_oak": "kindling", "kindling_heart": "kindling",
}
const WOODEN := ["wooden_pickaxe", "wooden_axe", "wooden_knife", "rod"]

static var _cache := {}


static func _pal(m: Color, acc: Color) -> Dictionary:
	return {"k": Color("1a1420"), "m": m, "l": m.lightened(0.4), "d": m.darkened(0.35), "w": Color("6b4a2c"), "h": Color("a47a4a"),
		"s": Color("dfe3ea"), "t": Color("8a90a0"), "g": acc, "y": Color("ffd24a"), "r": Color("e8643a"), "e": Color("1a1420")}


static func _paint(rows: Array, pal: Dictionary) -> ImageTexture:
	var n := rows.size()
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in mini(n, 16):
		var row: String = rows[y]
		for x in mini(16, row.length()):
			var ch := row[x]
			if pal.has(ch):
				img.set_pixel(x, y, pal[ch])
	return ImageTexture.create_from_image(img)


## Icon for a crafting material, tool or consumable by its Data.MATERIALS id.
static func material(id: String) -> ImageTexture:
	if _cache.has(id):
		return _cache[id]
	var d: Dictionary = Data.MATERIALS.get(id, {})
	var col := Color(d.get("color", "888888"))
	var shape: String = MAT_SHAPE.get(id, "")
	var tex: ImageTexture
	if id in ["knife", "wooden_knife"]:
		tex = _knife(col, id == "wooden_knife")
	elif shape == "":
		tex = _paint(SHAPES["ore"], _pal(col, col.lightened(0.5)))
	else:
		var acc := col.lightened(0.5)
		match shape:
			"potion":
				acc = Color("c8e8f0")
			"vial":
				col = Color("bfe8f0")
				acc = Color("dff4f8")
			"bud":
				acc = Color("4a9a3a")
			"log":
				acc = col.lightened(0.55)
			"flintsteel":
				acc = Color("8a8a92")
			"kindling":
				acc = Color("c8483a")
			"fish", "cooked":
				pass
		var pal := _pal(col, acc)
		if shape in ["pickaxe", "axe"] and id.begins_with("wooden"):
			pal["m"] = Color("a47a4a")
			pal["l"] = Color("c8a070")
		if shape == "log":
			pal["w"] = col.darkened(0.2)
			pal["h"] = col.lightened(0.25)
			pal["m"] = col.lightened(0.15)
		if shape in ["crystal"]:
			pal["m"] = col.darkened(0.05)
		tex = _paint(SHAPES[shape], pal)
	_cache[id] = tex
	return tex


static func _knife(col: Color, wooden: bool) -> ImageTexture:
	var rows: Array = []
	for r: String in Items.ICONS["dagger"]:
		rows.append(r + "    ")
	var pal := _pal(col, Color("6b4a2c"))
	pal["m"] = Color("a47a4a") if wooden else col
	pal["l"] = Color("c8a070") if wooden else col.lightened(0.4)
	pal["d"] = pal["m"].darkened(0.3)
	pal["g"] = Color("6b4a2c")
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in 12:
		var row: String = rows[y]
		for x in 12:
			var ch := row[x]
			if pal.has(ch):
				img.set_pixel(x + 2, y + 2, pal[ch])
	return ImageTexture.create_from_image(img)


## Icon for a skill, tinted with the skill's colour.
static func skill(id: String) -> ImageTexture:
	var key := "skill_" + id
	if _cache.has(key):
		return _cache[key]
	var col := Color(Data.SKILLS[id]["color"])
	var tex: ImageTexture
	match id:
		"mining":
			tex = material("pickaxe")
		"woodcutting":
			tex = material("axe")
		"fishing":
			tex = _paint(SHAPES["fish"], _pal(Color("7aa8d0"), col))
		"crafting":
			tex = _paint(SKILL_SHAPES["crafting"], _pal(col, col))
		"ranged":
			var rows: Array = ["", "", ""]
			for r: String in Items.ICONS["bow"]:
				rows.append("  " + r)
			var pal := _pal(Color("a47a4a"), col)
			pal["l"] = Color("e8e0d0")
			tex = _paint(rows, pal)
		"melee":
			tex = _paint(SKILL_SHAPES["melee"], _pal(col, col.lightened(0.2)))
		_:
			tex = _paint(SKILL_SHAPES[id], _pal(col, col.lightened(0.3)))
	_cache[key] = tex
	return tex


## Icon for an ability by Data.ABILITIES id; null when none is drawn (the slot shows initials instead).
static func ability(id: String) -> ImageTexture:
	if not ABILITY_SHAPES.has(id):
		return null
	var key := "ab_" + id
	if _cache.has(key):
		return _cache[key]
	var pal := {"k": Color("1a1420"), "s": Color("e8ecf2"), "t": Color("8a90a0"), "w": Color("6b4a2c"), "h": Color("a47a4a"),
		"g": Color("7ad84a"), "G": Color("3a8a2a"), "p": Color("b49aff"), "P": Color("6a52b8"), "r": Color("ff5a4a"), "R": Color("a01e2c"),
		"y": Color("ffd24a"), "o": Color("c8c8d8"), "O": Color("80809a"), "W": Color("ffffff"),
		"n": Color("ff9a3a"), "N": Color("c8501a"), "b": Color("8ae0ff"), "B": Color("3a80c0"), "c": Color("fff0b8"), "m": Color("7a6a58")}
	var tex := _paint(ABILITY_SHAPES[id], pal)
	_cache[key] = tex
	return tex


## Icon for a passive talent by its Data.TALENTS id; null when none is drawn.
static func talent(id: String) -> ImageTexture:
	if not TALENT_GLYPH.has(id):
		return null
	var key := "tl_" + id
	if _cache.has(key):
		return _cache[key]
	var acc := Color(TREE_TINT.get(id.get_slice("_", 0), "7ad84a"))
	var pal := {"k": Color("1a1420"), "a": acc, "A": acc.lightened(0.45), "B": acc.darkened(0.4), "s": Color("dfe3ea"), "t": Color("8a90a0"),
		"W": Color("ffffff"), "r": Color("e8483c"), "y": Color("ffd24a"), "o": Color("c8c8d8"), "w": Color("6b4a2c")}
	var tex := _paint(TALENT_SHAPES[TALENT_GLYPH[id]], pal)
	_cache[key] = tex
	return tex
