import 'dart:math' as math;
import 'package:get_storage/get_storage.dart';
import '../models/channel_live.dart';
import '../models/local_market_profile.dart';
import '../models/user_preference_profile.dart';
import 'provider_curation_rules.dart';

class LocalMarketService {
  static const String _marketCacheKey = "active_local_market_id";

  /// Unified Market Registry listing all 30 US markets with coordinates and station callsign aliases.
  static final List<LocalMarketProfile> supportedMarkets = [
    const LocalMarketProfile(
      id: "atlanta_ga",
      displayName: "Atlanta, GA",
      city: "Atlanta",
      state: "GA",
      timezone: "America/New_York",
      latitude: 33.7490,
      longitude: -84.3880,
      stationAliases: {
        "ABC": ["WSB", "WSB-TV", "WSB 2", "Channel 2 Atlanta", "ABC Atlanta", "ABC 2 Atlanta"],
        "FOX": ["WAGA", "WAGA-TV", "WAGA 5", "FOX 5", "FOX 5 Atlanta", "FOX Atlanta"],
        "NBC": ["WXIA", "WXIA-TV", "WXIA 11", "11Alive", "NBC Atlanta", "NBC 11 Atlanta"],
        "CBS": ["WUPA", "WUPA-TV", "WUPA 69", "CBS Atlanta", "CBS 69 Atlanta", "WANF", "WANF-TV", "CBS 46", "Atlanta News First", "WGCL"],
        "Independent": ["WPCH", "WPCH-TV", "WPCH 17", "Peachtree TV", "Peachtree Atlanta"],
        "CW": ["CW Atlanta", "Atlanta CW", "WATL", "WATL 36", "My ATL", "MyNetwork Atlanta"],
        "PBS": ["GPB", "Georgia PBS", "WGTV", "WGTV 8", "WPBA", "WPBA 30", "PBS Atlanta"],
        "Spanish": ["WUVG", "WUVG 34", "Univision Atlanta", "WKTB", "WKTB 47", "Telemundo Atlanta"]
      },
      sportsAliases: ["Bally Sports South", "Bally Sports Southeast", "Atlanta Hawks", "Atlanta Braves", "Atlanta Falcons"],
      newsAliases: ["Atlanta News First", "Fox 5 Atlanta News", "WSB News", "11Alive News"],
      spanishAliases: ["Univision 34 Atlanta", "Telemundo Atlanta"],
      nearbyMarkets: ["birmingham_al", "nashville_tn", "charlotte_nc"],
    ),
    const LocalMarketProfile(
      id: "dallas_fort_worth_tx",
      displayName: "Dallas-Fort Worth, TX",
      city: "Dallas",
      state: "TX",
      timezone: "America/Chicago",
      latitude: 32.7767,
      longitude: -96.7970,
      stationAliases: {
        "ABC": ["WFAA", "ABC Dallas", "ABC DFW", "Channel 8", "WFAA 8"],
        "FOX": ["KDFW", "FOX 4", "FOX Dallas", "FOX DFW"],
        "NBC": ["KXAS", "NBC 5", "NBC DFW", "NBC Dallas"],
        "CBS": ["KTVT", "CBS Texas", "CBS 11", "CBS Dallas", "CBS DFW"],
        "CW": ["KDAF", "CW 33", "Dallas CW"],
        "PBS": ["KERA", "KERA-TV", "KERA PBS", "PBS Dallas"],
        "Spanish": ["KUVN", "Univision Dallas", "KXTX", "Telemundo Dallas"],
        "LocalIndependent": ["KTXA", "TXA 21"]
      },
      sportsAliases: ["Bally Sports Southwest", "Dallas Mavericks", "Dallas Cowboys", "Texas Rangers", "Dallas Stars"],
      newsAliases: ["NBC DFW News", "WFAA News", "CBS Texas News", "Fox 4 News Dallas"],
      spanishAliases: ["Univision Dallas", "Telemundo 39"],
      nearbyMarkets: ["houston_tx", "new_orleans_la"],
    ),
    const LocalMarketProfile(
      id: "houston_tx",
      displayName: "Houston, TX",
      city: "Houston",
      state: "TX",
      timezone: "America/Chicago",
      latitude: 29.7604,
      longitude: -95.3698,
      stationAliases: {
        "ABC": ["KTRK", "ABC 13", "ABC Houston", "KTRK-TV"],
        "FOX": ["KRIV", "FOX 26", "FOX Houston", "KRIV-TV"],
        "NBC": ["KPRC", "NBC 2", "KPRC 2", "NBC Houston", "KPRC-TV"],
        "CBS": ["KHOU", "CBS 11", "KHOU 11", "CBS Houston", "KHOU-TV"],
        "CW": ["KIAH", "CW 39", "Houston CW"],
        "PBS": ["KUHT", "Houston Public Media", "PBS Houston"],
        "Spanish": ["KXLN", "Univision Houston", "KTMD", "Telemundo Houston"],
        "LocalIndependent": ["KTBU", "Quest Houston"]
      },
      sportsAliases: ["Space City Home Network", "Houston Astros", "Houston Rockets", "Houston Texans"],
      newsAliases: ["KPRC 2 News", "KHOU 11 News", "ABC 13 Eyewitness News", "Fox 26 Houston News"],
      spanishAliases: ["Univision 45 Houston", "Telemundo 47 Houston"],
      nearbyMarkets: ["dallas_fort_worth_tx", "new_orleans_la"],
    ),
    const LocalMarketProfile(
      id: "new_york_ny",
      displayName: "New York, NY",
      city: "New York",
      state: "NY",
      timezone: "America/New_York",
      latitude: 40.7128,
      longitude: -74.0060,
      stationAliases: {
        "ABC": ["WABC", "ABC 7 NY", "ABC New York", "WABC-TV", "Channel 7 NY"],
        "FOX": ["WNYW", "FOX 5 NY", "FOX New York", "WNYW-TV"],
        "NBC": ["WNBC", "NBC 4 NY", "NBC New York", "WNBC-TV", "Channel 4 NY"],
        "CBS": ["WCBS", "CBS 2 NY", "CBS New York", "WCBS-TV", "Channel 2 NY"],
        "CW": ["WPIX", "PIX11", "WPIX-TV", "CW New York", "CW11"],
        "PBS": ["WNET", "Thirteen", "WLIW", "NJ PBS", "PBS New York"],
        "Spanish": ["WXTV", "Univision NY", "WNJU", "Telemundo NY"],
        "LocalIndependent": ["WNYE", "NYC Life"]
      },
      sportsAliases: ["YES Network", "SNY", "MSG", "MSG Plus", "New York Yankees", "New York Mets", "New York Knicks", "New York Giants", "New York Jets"],
      newsAliases: ["ABC7 Eyewitness News", "NBC 4 New York News", "CBS 2 New York News", "Fox 5 NY News", "PIX11 News"],
      spanishAliases: ["Univision 41 Nueva York", "Telemundo 47"],
      nearbyMarkets: ["philadelphia_pa", "boston_ma"],
    ),
    const LocalMarketProfile(
      id: "los_angeles_ca",
      displayName: "Los Angeles, CA",
      city: "Los Angeles",
      state: "CA",
      timezone: "America/Los_Angeles",
      latitude: 34.0522,
      longitude: -118.2437,
      stationAliases: {
        "ABC": ["KABC", "ABC 7 LA", "ABC Los Angeles", "KABC-TV", "Channel 7 LA"],
        "FOX": ["KTTV", "FOX 11 LA", "FOX Los Angeles", "KTTV-TV"],
        "NBC": ["KNBC", "NBC 4 LA", "NBC Los Angeles", "KNBC-TV", "Channel 4 LA"],
        "CBS": ["KCBS", "CBS 2 LA", "CBS Los Angeles", "KCBS-TV", "Channel 2 LA"],
        "CW": ["KTLA", "KTLA 5", "KTLA-TV", "CW Los Angeles", "CW5"],
        "PBS": ["KCET", "KLCS", "KVCR", "PBS SoCal", "PBS Los Angeles"],
        "Spanish": ["KMEX", "Univision 34", "KVEA", "Telemundo 52"],
        "LocalIndependent": ["KCAL", "KCAL 9", "KCAL-TV", "KCOP", "My13 LA"]
      },
      sportsAliases: ["Spectrum SportsNet", "SportsNet LA", "Los Angeles Lakers", "Los Angeles Clippers", "Los Angeles Dodgers", "Los Angeles Angels", "Los Angeles Rams", "Los Angeles Chargers"],
      newsAliases: ["KTLA 5 News", "KCAL News", "KABC 7 Eyewitness News", "KNBC 4 News"],
      spanishAliases: ["Univision 34 Los Angeles", "Telemundo 52 Los Angeles"],
      nearbyMarkets: ["san_diego_ca", "sacramento_ca", "las_vegas_nv"],
    ),
    const LocalMarketProfile(
      id: "chicago_il",
      displayName: "Chicago, IL",
      city: "Chicago",
      state: "IL",
      timezone: "America/Chicago",
      latitude: 41.8781,
      longitude: -87.6298,
      stationAliases: {
        "ABC": ["WLS", "WLS-TV", "ABC 7 Chicago", "ABC Chicago"],
        "FOX": ["WFLD", "FOX 32 Chicago", "FOX Chicago", "WFLD-TV"],
        "NBC": ["WMAQ", "WMAQ-TV", "NBC 5 Chicago", "NBC Chicago"],
        "CBS": ["WBBM", "WBBM-TV", "CBS 2 Chicago", "CBS Chicago"],
        "CW": ["WGN", "WGN-TV", "WGN 9", "Chicago CW", "CW Chicago"],
        "PBS": ["WTTW", "WTTW 11", "PBS Chicago"],
        "Spanish": ["WGBO", "Univision Chicago", "WSNS", "Telemundo Chicago"],
        "LocalIndependent": ["WCIU", "The U"]
      },
      sportsAliases: ["Marquee Sports Network", "NBC Sports Chicago", "Chicago Cubs", "Chicago White Sox", "Chicago Bulls", "Chicago Bears"],
      newsAliases: ["WGN News", "ABC 7 Chicago News", "NBC 5 Chicago News", "CBS 2 Chicago News"],
      spanishAliases: ["Univision Chicago", "Telemundo Chicago"],
      nearbyMarkets: ["indianapolis_in", "detroit_mi"],
    ),
    const LocalMarketProfile(
      id: "philadelphia_pa",
      displayName: "Philadelphia, PA",
      city: "Philadelphia",
      state: "PA",
      timezone: "America/New_York",
      latitude: 39.9526,
      longitude: -75.1652,
      stationAliases: {
        "ABC": ["WPVI", "WPVI-TV", "6ABC", "ABC 6 Philadelphia", "ABC Philly"],
        "FOX": ["WTXF", "FOX 29 Philadelphia", "FOX Philly", "WTXF-TV"],
        "NBC": ["WCAU", "NBC 10 Philadelphia", "NBC Philly", "WCAU-TV"],
        "CBS": ["KYW", "CBS News Philadelphia", "CBS Philly", "KYW-TV", "CBS 3"],
        "CW": ["WPSG", "CW Philly", "CW 57"],
        "PBS": ["WHYY", "WHYY-TV", "PBS Philly", "PBS Philadelphia"],
        "Spanish": ["WUVP", "Univision Philadelphia", "WWSI", "Telemundo Philadelphia"],
        "LocalIndependent": ["WPHL", "PHL17"]
      },
      sportsAliases: ["NBC Sports Philadelphia", "Philadelphia Phillies", "Philadelphia 76ers", "Philadelphia Eagles", "Philadelphia Flyers"],
      newsAliases: ["6ABC Action News", "NBC 10 News", "CBS Philadelphia News", "FOX 29 News"],
      spanishAliases: ["Univision 65", "Telemundo 62"],
      nearbyMarkets: ["new_york_ny", "washington_dc"],
    ),
    const LocalMarketProfile(
      id: "miami_fl",
      displayName: "Miami-Fort Lauderdale, FL",
      city: "Miami",
      state: "FL",
      timezone: "America/New_York",
      latitude: 25.7617,
      longitude: -80.1918,
      stationAliases: {
        "ABC": ["WPLG", "Local 10", "WPLG-TV", "ABC Miami", "ABC 10"],
        "FOX": ["WSVN", "WSVN 7", "FOX 7 Miami", "FOX Miami"],
        "NBC": ["WTVJ", "NBC 6 Miami", "NBC Miami", "WTVJ-TV"],
        "CBS": ["WFOR", "CBS Miami", "CBS4 Miami", "WFOR-TV"],
        "CW": ["WSFL", "CW 39 Miami", "Miami CW"],
        "PBS": ["WPBT", "WLRN", "PBS Miami"],
        "Spanish": ["WLTV", "Univision 23", "WSCV", "Telemundo 51"],
        "LocalIndependent": ["WAMI", "UniMas Miami"]
      },
      sportsAliases: ["Bally Sports Florida", "Bally Sports Sun", "Miami Heat", "Miami Marlins", "Miami Dolphins", "Florida Panthers"],
      newsAliases: ["Local 10 News", "7 News WSVN", "CBS Miami News", "NBC 6 News Miami"],
      spanishAliases: ["Univision 23 Miami", "Telemundo 51 Miami"],
      nearbyMarkets: ["tampa_fl", "orlando_fl"],
    ),
    const LocalMarketProfile(
      id: "washington_dc",
      displayName: "Washington, DC",
      city: "Washington",
      state: "DC",
      timezone: "America/New_York",
      latitude: 38.9072,
      longitude: -77.0369,
      stationAliases: {
        "ABC": ["WJLA", "WJLA-TV", "7News DC", "ABC 7 DC", "ABC Washington"],
        "FOX": ["WTTG", "FOX 5 DC", "FOX Washington", "WTTG-TV"],
        "NBC": ["WRC", "NBC 4 Washington", "NBC4 DC", "WRC-TV"],
        "CBS": ["WUSA", "WUSA 9", "CBS Washington", "CBS 9 DC", "WUSA-TV"],
        "CW": ["WDCW", "CW 50", "DC CW"],
        "PBS": ["WETA", "WETA PBS", "WHUT", "PBS Washington"],
        "Spanish": ["WFDC", "Univision Washington", "WZDC", "Telemundo Washington"],
        "LocalIndependent": ["WDCA", "FOX 5 Plus"]
      },
      sportsAliases: ["Monumental Sports Network", "Washington Wizards", "Washington Nationals", "Washington Commanders", "Washington Capitals"],
      newsAliases: ["7News DC WJLA", "NBC 4 Washington News", "WUSA 9 News", "FOX 5 DC News"],
      spanishAliases: ["Univision Washington", "Telemundo Washington"],
      nearbyMarkets: ["philadelphia_pa", "birmingham_al"],
    ),
    const LocalMarketProfile(
      id: "san_francisco_ca",
      displayName: "San Francisco Bay Area, CA",
      city: "San Francisco",
      state: "CA",
      timezone: "America/Los_Angeles",
      latitude: 37.7749,
      longitude: -122.4194,
      stationAliases: {
        "ABC": ["KGO", "KGO-TV", "ABC 7 San Francisco", "ABC7 Bay Area"],
        "FOX": ["KTVU", "KTVU FOX 2", "FOX 2 Oakland", "FOX Bay Area", "KTVU-TV"],
        "NBC": ["KNTV", "NBC Bay Area", "NBC 11", "KNTV-TV"],
        "CBS": ["KPIX", "KPIX 5", "CBS Bay Area", "CBS San Francisco", "KPIX-TV"],
        "CW": ["KBCW", "KPYX", "KPIX+ CBS Bay Area", "Bay Area CW"],
        "PBS": ["KQED", "KQED PBS", "PBS San Francisco"],
        "Spanish": ["KDTV", "Univision 14 Bay Area", "KSTS", "Telemundo 48"],
        "LocalIndependent": ["KOFY", "KOFY TV 20"]
      },
      sportsAliases: ["NBC Sports Bay Area", "NBC Sports California", "Golden State Warriors", "San Francisco Giants", "San Francisco 49ers"],
      newsAliases: ["ABC 7 News Bay Area", "KTVU Fox 2 News", "KPIX CBS Bay Area News", "NBC Bay Area News"],
      spanishAliases: ["Univision 14 KDTV", "Telemundo 48 KSTS"],
      nearbyMarkets: ["sacramento_ca", "san_diego_ca", "seattle_wa"],
    ),
    // Expanded Markets (Unlimited expansion architecture)
    const LocalMarketProfile(
      id: "charlotte_nc",
      displayName: "Charlotte, NC",
      city: "Charlotte",
      state: "NC",
      timezone: "America/New_York",
      latitude: 35.2271,
      longitude: -80.8431,
      stationAliases: {
        "ABC": ["WSOC", "WSOC-TV", "Channel 9 Charlotte", "ABC Charlotte"],
        "FOX": ["WJZY", "FOX 46 Charlotte", "FOX Charlotte"],
        "NBC": ["WCNC", "WCNC-TV", "NBC Charlotte", "WCNC 36"],
        "CBS": ["WBTV", "WBTV-TV", "CBS 3 Charlotte", "CBS Charlotte"],
        "CW": ["WCCB", "WCCB Charlotte", "Charlotte CW"],
        "PBS": ["WTVI", "PBS Charlotte"]
      },
      sportsAliases: ["Bally Sports South", "Charlotte Hornets", "Carolina Panthers"],
      newsAliases: ["WSOC-TV News", "WBTV News", "WCNC News", "FOX 46 Charlotte News"],
      spanishAliases: [],
      nearbyMarkets: ["atlanta_ga", "washington_dc"],
    ),
    const LocalMarketProfile(
      id: "new_orleans_la",
      displayName: "New Orleans, LA",
      city: "New Orleans",
      state: "LA",
      timezone: "America/Chicago",
      latitude: 29.9511,
      longitude: -90.0715,
      stationAliases: {
        "ABC": ["WGNO", "WGNO-TV", "ABC New Orleans", "WGNO 26"],
        "FOX": ["WVUE", "FOX 8 New Orleans", "FOX New Orleans"],
        "NBC": ["WDSU", "WDSU-TV", "NBC New Orleans", "NBC 6"],
        "CBS": ["WWL", "WWL-TV", "CBS New Orleans", "Eyewitness News WWL"],
        "CW": ["WNOL", "NOLA CW", "CW 38"],
        "PBS": ["WYES", "WYES-TV", "PBS New Orleans"]
      },
      sportsAliases: ["Gulf Coast Sports", "New Orleans Pelicans", "New Orleans Saints"],
      newsAliases: ["WWL-TV Eyewitness News", "WDSU News", "FOX 8 Local News"],
      spanishAliases: [],
      nearbyMarkets: ["houston_tx", "birmingham_al", "memphis_tn"],
    ),
    const LocalMarketProfile(
      id: "memphis_tn",
      displayName: "Memphis, TN",
      city: "Memphis",
      state: "TN",
      timezone: "America/Chicago",
      latitude: 35.1495,
      longitude: -90.0490,
      stationAliases: {
        "ABC": ["WATN", "Local 24 Memphis", "ABC Memphis"],
        "FOX": ["WHBQ", "FOX 13 Memphis", "FOX Memphis"],
        "NBC": ["WMC", "WMC-TV", "NBC 5 Memphis", "Action News 5"],
        "CBS": ["WREG", "WREG-TV", "CBS 3 Memphis", "CBS Memphis"],
        "CW": ["WLMT", "CW 30 Memphis"],
        "PBS": ["WKNO", "WKNO-TV", "PBS Memphis"]
      },
      sportsAliases: ["Memphis Grizzlies"],
      newsAliases: ["WREG News Channel 3", "Action News 5 Memphis", "FOX 13 Memphis News"],
      spanishAliases: [],
      nearbyMarkets: ["nashville_tn", "new_orleans_la", "st_louis_mo"],
    ),
    const LocalMarketProfile(
      id: "nashville_tn",
      displayName: "Nashville, TN",
      city: "Nashville",
      state: "TN",
      timezone: "America/Chicago",
      latitude: 36.1627,
      longitude: -86.7816,
      stationAliases: {
        "ABC": ["WKRN", "News 2 Nashville", "ABC Nashville", "WKRN-TV"],
        "FOX": ["WZTV", "FOX 17 Nashville", "FOX Nashville"],
        "NBC": ["WSMV", "WSMV 4 Nashville", "NBC Nashville"],
        "CBS": ["WTVF", "NewsChannel 5 Nashville", "CBS Nashville", "WTVF 5"],
        "CW": ["WUXP", "MyTV 30", "CW 58"],
        "PBS": ["WNPT", "Nashville Public Television", "PBS Nashville"]
      },
      sportsAliases: ["Bally Sports South", "Nashville Predators", "Tennessee Titans"],
      newsAliases: ["NewsChannel 5 Nashville", "WSMV 4 News", "WKRN News 2"],
      spanishAliases: [],
      nearbyMarkets: ["atlanta_ga", "memphis_tn", "birmingham_al"],
    ),
    const LocalMarketProfile(
      id: "birmingham_al",
      displayName: "Birmingham, AL",
      city: "Birmingham",
      state: "AL",
      timezone: "America/Chicago",
      latitude: 33.5186,
      longitude: -86.8104,
      stationAliases: {
        "ABC": ["WBMA", "ABC 33/40", "ABC Birmingham"],
        "FOX": ["WBRC", "FOX 6 Birmingham", "FOX WBRC"],
        "NBC": ["WVTM", "WVTM 13", "NBC Birmingham", "WVTM-TV"],
        "CBS": ["WIAT", "CBS 42 Birmingham", "WIAT-TV"],
        "CW": ["WTTO", "CW 21 Birmingham"],
        "PBS": ["WBIQ", "APT Birmingham", "Alabama Public Television"]
      },
      sportsAliases: ["Bally Sports South", "Alabama Crimson Tide", "Auburn Tigers"],
      newsAliases: ["WBRC FOX 6 News", "ABC 33/40 News", "WVTM 13 News"],
      spanishAliases: [],
      nearbyMarkets: ["atlanta_ga", "nashville_tn", "new_orleans_la"],
    ),
    const LocalMarketProfile(
      id: "tampa_fl",
      displayName: "Tampa-St. Petersburg, FL",
      city: "Tampa",
      state: "FL",
      timezone: "America/New_York",
      latitude: 27.9506,
      longitude: -82.4572,
      stationAliases: {
        "ABC": ["WFTS", "ABC Action News Tampa", "ABC Tampa", "WFTS-TV"],
        "FOX": ["WTVT", "FOX 13 Tampa", "FOX Tampa", "WTVT-TV"],
        "NBC": ["WFLA", "NBC 8 Tampa", "News Channel 8", "WFLA-TV"],
        "CBS": ["WTSP", "10 Tampa Bay", "CBS Tampa", "WTSP-TV"],
        "CW": ["WTOG", "CW 44 Tampa"],
        "PBS": ["WEDU", "WEDU PBS", "PBS Tampa"]
      },
      sportsAliases: ["Bally Sports Florida", "Tampa Bay Buccaneers", "Tampa Bay Rays", "Tampa Bay Lightning"],
      newsAliases: ["FOX 13 Tampa News", "WFLA News Channel 8", "ABC Action News Tampa"],
      spanishAliases: [],
      nearbyMarkets: ["miami_fl", "orlando_fl"],
    ),
    const LocalMarketProfile(
      id: "orlando_fl",
      displayName: "Orlando, FL",
      city: "Orlando",
      state: "FL",
      timezone: "America/New_York",
      latitude: 28.5383,
      longitude: -81.3792,
      stationAliases: {
        "ABC": ["WFTV", "Channel 9 Orlando", "ABC Orlando", "WFTV-TV"],
        "FOX": ["WOFL", "FOX 35 Orlando", "FOX Orlando", "WOFL-TV"],
        "NBC": ["WESH", "WESH 2 NBC", "NBC Orlando", "WESH-TV"],
        "CBS": ["WKMG", "News 6 Orlando", "CBS Orlando", "WKMG-TV"],
        "CW": ["WKCF", "CW 18 Orlando"],
        "PBS": ["WUCF", "WUCF PBS", "PBS Orlando"]
      },
      sportsAliases: ["Bally Sports Florida", "Orlando Magic", "Orlando City SC"],
      newsAliases: ["WFTV Channel 9 News", "WESH 2 News", "News 6 WKMG"],
      spanishAliases: [],
      nearbyMarkets: ["miami_fl", "tampa_fl"],
    ),
    const LocalMarketProfile(
      id: "phoenix_az",
      displayName: "Phoenix, AZ",
      city: "Phoenix",
      state: "AZ",
      timezone: "America/Phoenix",
      latitude: 33.4484,
      longitude: -112.0740,
      stationAliases: {
        "ABC": ["KNXV", "ABC 15 Phoenix", "ABC Phoenix", "KNXV-TV"],
        "FOX": ["KSAZ", "FOX 10 Phoenix", "FOX Phoenix", "KSAZ-TV"],
        "NBC": ["KPNX", "12 News Phoenix", "NBC Phoenix", "KPNX-TV"],
        "CBS": ["KPHO", "CBS 5 Phoenix", "CBS Phoenix", "KPHO-TV"],
        "CW": ["KASW", "Arizona CW", "CW 61"],
        "PBS": ["KAET", "Arizona PBS", "PBS Phoenix"]
      },
      sportsAliases: ["Arizona Diamondbacks", "Phoenix Suns", "Arizona Cardinals", "Arizona Coyotes"],
      newsAliases: ["ABC 15 Phoenix News", "FOX 10 Phoenix News", "12 News Arizona"],
      spanishAliases: ["Univision Arizona", "Telemundo Arizona"],
      nearbyMarkets: ["los_angeles_ca", "san_diego_ca", "las_vegas_nv"],
    ),
    const LocalMarketProfile(
      id: "seattle_wa",
      displayName: "Seattle-Tacoma, WA",
      city: "Seattle",
      state: "WA",
      timezone: "America/Los_Angeles",
      latitude: 47.6062,
      longitude: -122.3321,
      stationAliases: {
        "ABC": ["KOMO", "KOMO 4 Seattle", "ABC Seattle", "KOMO-TV"],
        "FOX": ["KCPQ", "FOX 13 Seattle", "FOX Seattle", "KCPQ-TV"],
        "NBC": ["KING", "KING 5 NBC", "NBC Seattle", "KING-TV"],
        "CBS": ["KIRO", "KIRO 7 CBS", "CBS Seattle", "KIRO-TV"],
        "CW": ["KONG", "KONG Seattle", "Independent 16"],
        "PBS": ["KCTS", "Cascade PBS", "PBS Seattle", "KCTS 9"]
      },
      sportsAliases: ["Root Sports Northwest", "Seattle Mariners", "Seattle Seahawks", "Seattle Kraken", "Seattle Sounders"],
      newsAliases: ["KOMO News 4", "KING 5 News", "KIRO 7 News"],
      spanishAliases: [],
      nearbyMarkets: ["san_francisco_ca"],
    ),
    const LocalMarketProfile(
      id: "boston_ma",
      displayName: "Boston, MA",
      city: "Boston",
      state: "MA",
      timezone: "America/New_York",
      latitude: 42.3601,
      longitude: -71.0589,
      stationAliases: {
        "ABC": ["WCVB", "WCVB 5 Boston", "ABC Boston", "WCVB-TV"],
        "FOX": ["WFXT", "Boston 25 FOX", "FOX Boston", "WFXT-TV"],
        "NBC": ["WBTS", "NBC10 Boston", "NBC Boston", "WBTS-CD"],
        "CBS": ["WBZ", "CBS News Boston", "CBS Boston", "WBZ-TV", "CBS 4"],
        "CW": ["WLVI", "CW 56 Boston"],
        "PBS": ["WGBH", "GBH 2 Boston", "PBS Boston"]
      },
      sportsAliases: ["NESN", "Boston Red Sox", "Boston Celtics", "New England Patriots", "Boston Bruins"],
      newsAliases: ["WCVB NewsCenter 5", "Boston 25 News", "WBZ-TV News"],
      spanishAliases: [],
      nearbyMarkets: ["new_york_ny"],
    ),
    const LocalMarketProfile(
      id: "detroit_mi",
      displayName: "Detroit, MI",
      city: "Detroit",
      state: "MI",
      timezone: "America/Detroit",
      latitude: 42.3314,
      longitude: -83.0458,
      stationAliases: {
        "ABC": ["WXYZ", "WXYZ 7 Detroit", "ABC Detroit", "WXYZ-TV"],
        "FOX": ["WJBK", "FOX 2 Detroit", "FOX Detroit", "WJBK-TV"],
        "NBC": ["WDIV", "Local 4 Detroit", "NBC Detroit", "WDIV-TV"],
        "CBS": ["WWJ", "CBS News Detroit", "CBS Detroit", "WWJ-TV"],
        "CW": ["WKBD", "CW 50 Detroit"],
        "PBS": ["WTVS", "Detroit Public TV", "PBS Detroit"]
      },
      sportsAliases: ["Bally Sports Detroit", "Detroit Tigers", "Detroit Pistons", "Detroit Lions", "Detroit Red Wings"],
      newsAliases: ["Local 4 News WDIV", "WXYZ 7 Action News", "FOX 2 News Detroit"],
      spanishAliases: [],
      nearbyMarkets: ["chicago_il", "cleveland_oh"],
    ),
    const LocalMarketProfile(
      id: "las_vegas_nv",
      displayName: "Las Vegas, NV",
      city: "Las Vegas",
      state: "NV",
      timezone: "America/Los_Angeles",
      latitude: 36.1716,
      longitude: -115.1398,
      stationAliases: {
        "ABC": ["KTNV", "13 Action News Vegas", "ABC Las Vegas"],
        "FOX": ["KVVU", "FOX 5 Vegas", "FOX Las Vegas"],
        "NBC": ["KSNV", "News 3 Las Vegas", "NBC Las Vegas"],
        "CBS": ["KLAS", "8 News Now Vegas", "CBS Las Vegas"],
        "CW": ["KVCW", "CW Las Vegas", "Vegas CW"],
        "PBS": ["KLVX", "Vegas PBS", "PBS Las Vegas"]
      },
      sportsAliases: ["Vegas Golden Knights", "Las Vegas Raiders", "Las Vegas Aces"],
      newsAliases: ["8 News Now KLAS", "News 3 KSNV", "13 Action News KTNV"],
      spanishAliases: [],
      nearbyMarkets: ["los_angeles_ca", "phoenix_az", "denver_co"],
    ),
    const LocalMarketProfile(
      id: "denver_co",
      displayName: "Denver, CO",
      city: "Denver",
      state: "CO",
      timezone: "America/Denver",
      latitude: 39.7392,
      longitude: -104.9903,
      stationAliases: {
        "ABC": ["KMGH", "Denver7 ABC", "ABC Denver", "KMGH-TV"],
        "FOX": ["KDVR", "FOX 31 Denver", "FOX Denver", "KDVR-TV"],
        "NBC": ["KUSA", "9News Denver", "NBC Denver", "KUSA-TV"],
        "CBS": ["KCNC", "CBS News Colorado", "CBS Denver", "KCNC-TV"],
        "CW": ["KWGN", "Colorado's Own 2", "CW Denver"],
        "PBS": ["KRMA", "Rocky Mountain PBS", "PBS Denver"]
      },
      sportsAliases: ["Altitude Sports", "Colorado Rockies", "Denver Nuggets", "Denver Broncos", "Colorado Avalanche"],
      newsAliases: ["9News Denver KUSA", "Denver7 News KMGH", "CBS Colorado KCNC"],
      spanishAliases: [],
      nearbyMarkets: ["las_vegas_nv", "kansas_city_mo"],
    ),
    const LocalMarketProfile(
      id: "san_diego_ca",
      displayName: "San Diego, CA",
      city: "San Diego",
      state: "CA",
      timezone: "America/Los_Angeles",
      latitude: 32.7157,
      longitude: -117.1611,
      stationAliases: {
        "ABC": ["KGTV", "ABC 10 San Diego", "ABC San Diego"],
        "FOX": ["KSWB", "FOX 5 San Diego", "FOX San Diego"],
        "NBC": ["KNSD", "NBC 7 San Diego", "NBC San Diego"],
        "CBS": ["KFMB", "CBS 8 San Diego", "CBS San Diego"],
        "CW": ["XETV", "San Diego CW", "CW6"],
        "PBS": ["KPBS", "KPBS-TV", "PBS San Diego"]
      },
      sportsAliases: ["San Diego Padres"],
      newsAliases: ["CBS 8 San Diego News", "NBC 7 San Diego News", "FOX 5 San Diego News"],
      spanishAliases: [],
      nearbyMarkets: ["los_angeles_ca", "phoenix_az"],
    ),
    const LocalMarketProfile(
      id: "sacramento_ca",
      displayName: "Sacramento, CA",
      city: "Sacramento",
      state: "CA",
      timezone: "America/Los_Angeles",
      latitude: 38.5816,
      longitude: -121.4944,
      stationAliases: {
        "ABC": ["KXTV", "ABC10 Sacramento", "ABC Sacramento"],
        "FOX": ["KTXL", "FOX40 Sacramento", "FOX Sacramento"],
        "NBC": ["KCRA", "KCRA 3 NBC", "NBC Sacramento", "KCRA-TV"],
        "CBS": ["KOVR", "CBS13 Sacramento", "CBS Sacramento", "KOVR-TV"],
        "CW": ["KMAX", "Good Day Sacramento", "CW31"],
        "PBS": ["KVIE", "KVIE PBS", "PBS Sacramento"]
      },
      sportsAliases: ["Sacramento Kings"],
      newsAliases: ["KCRA 3 News", "CBS13 News KOVR", "ABC10 News KXTV"],
      spanishAliases: [],
      nearbyMarkets: ["san_francisco_ca", "los_angeles_ca"],
    ),
    const LocalMarketProfile(
      id: "cleveland_oh",
      displayName: "Cleveland, OH",
      city: "Cleveland",
      state: "OH",
      timezone: "America/New_York",
      latitude: 41.4993,
      longitude: -81.6944,
      stationAliases: {
        "ABC": ["WEWS", "News 5 Cleveland", "ABC Cleveland", "WEWS-TV"],
        "FOX": ["WJW", "FOX 8 Cleveland", "FOX Cleveland", "WJW-TV"],
        "NBC": ["WKYC", "3News Cleveland", "NBC Cleveland", "WKYC-TV"],
        "CBS": ["WOIO", "19 News Cleveland", "CBS Cleveland", "WOIO-TV"],
        "CW": ["WUAB", "Cleveland 19 CW", "CW 43"],
        "PBS": ["WVIZ", "Ideastream PBS", "PBS Cleveland"]
      },
      sportsAliases: ["Bally Sports Great Lakes", "Cleveland Guardians", "Cleveland Cavaliers", "Cleveland Browns"],
      newsAliases: ["FOX 8 News Cleveland", "3News WKYC", "19 News Cleveland WOIO"],
      spanishAliases: [],
      nearbyMarkets: ["detroit_mi", "indianapolis_in"],
    ),
    const LocalMarketProfile(
      id: "st_louis_mo",
      displayName: "St. Louis, MO",
      city: "St. Louis",
      state: "MO",
      timezone: "America/Chicago",
      latitude: 38.6270,
      longitude: -90.1994,
      stationAliases: {
        "ABC": ["KDNL", "ABC 30 St. Louis", "ABC St. Louis"],
        "FOX": ["KTVI", "FOX 2 St. Louis", "FOX St. Louis"],
        "NBC": ["KSDK", "5 On Your Side", "NBC St. Louis", "KSDK 5"],
        "CBS": ["KMOV", "First Alert 4 St. Louis", "CBS St. Louis", "KMOV 4"],
        "CW": ["KPLR", "KPLR 11", "CW St. Louis"],
        "PBS": ["KETC", "Nine PBS", "PBS St. Louis"]
      },
      sportsAliases: ["Bally Sports Midwest", "St. Louis Cardinals", "St. Louis Blues", "St. Louis City SC"],
      newsAliases: ["5 On Your Side News KSDK", "First Alert 4 News KMOV", "FOX 2 News KTVI"],
      spanishAliases: [],
      nearbyMarkets: ["chicago_il", "memphis_tn", "kansas_city_mo"],
    ),
    const LocalMarketProfile(
      id: "kansas_city_mo",
      displayName: "Kansas City, MO",
      city: "Kansas City",
      state: "MO",
      timezone: "America/Chicago",
      latitude: 39.0997,
      longitude: -94.5786,
      stationAliases: {
        "ABC": ["KMBC", "KMBC 9 news", "ABC Kansas City"],
        "FOX": ["WDAF", "FOX 4 Kansas City", "FOX KC"],
        "NBC": ["KSHB", "KSHB 41 Action News", "NBC Kansas City"],
        "CBS": ["KCTV", "KCTV5 News", "CBS Kansas City"],
        "CW": ["KCWE", "CW 29 KC", "CW Kansas City"],
        "PBS": ["KCPT", "Kansas City PBS"]
      },
      sportsAliases: ["Bally Sports Midwest", "Kansas City Royals", "Kansas City Chiefs"],
      newsAliases: ["KMBC 9 News", "FOX 4 News Kansas City", "KSHB 41 News"],
      spanishAliases: [],
      nearbyMarkets: ["st_louis_mo", "denver_co", "minneapolis_mn"],
    ),
    const LocalMarketProfile(
      id: "indianapolis_in",
      displayName: "Indianapolis, IN",
      city: "Indianapolis",
      state: "IN",
      timezone: "America/Indiana/Indianapolis",
      latitude: 39.7684,
      longitude: -86.1581,
      stationAliases: {
        "ABC": ["WRTV", "WRTV Indianapolis", "ABC Indy", "ABC Indianapolis"],
        "FOX": ["WXIN", "FOX 59 Indianapolis", "FOX Indy"],
        "NBC": ["WTHR", "13News Indy", "NBC Indianapolis", "WTHR 13"],
        "CBS": ["WTTV", "CBS 4 Indy", "CBS Indianapolis"],
        "CW": ["WISH", "WISH-TV", "News 8 Indy", "CW Indianapolis"],
        "PBS": ["WFYI", "WFYI PBS", "PBS Indianapolis"]
      },
      sportsAliases: ["Bally Sports Indiana", "Indiana Pacers", "Indianapolis Colts"],
      newsAliases: ["FOX 59 News Indy", "13News WTHR", "News 8 WISH-TV"],
      spanishAliases: [],
      nearbyMarkets: ["chicago_il", "cleveland_oh", "detroit_mi"],
    ),
    const LocalMarketProfile(
      id: "minneapolis_mn",
      displayName: "Minneapolis-St. Paul, MN",
      city: "Minneapolis",
      state: "MN",
      timezone: "America/Chicago",
      latitude: 44.9778,
      longitude: -93.2650,
      stationAliases: {
        "ABC": ["KSTP", "KSTP 5", "ABC Minneapolis", "ABC Twin Cities"],
        "FOX": ["KMSP", "FOX 9 Minneapolis", "FOX Twin Cities"],
        "NBC": ["KARE", "KARE 11", "NBC Minneapolis", "NBC Twin Cities"],
        "CBS": ["WCCO", "WCCO 4 News", "CBS Minneapolis", "CBS Twin Cities"],
        "CW": ["WFTC", "FOX 9 Plus", "CW Minneapolis"],
        "PBS": ["KTCA", "TPT PBS", "Twin Cities PBS"]
      },
      sportsAliases: ["Bally Sports North", "Minnesota Twins", "Minnesota Timberwolves", "Minnesota Vikings", "Minnesota Wild"],
      newsAliases: ["WCCO 4 News Minneapolis", "KARE 11 News", "FOX 9 Minneapolis News"],
      spanishAliases: [],
      nearbyMarkets: ["chicago_il", "kansas_city_mo"],
    ),
  ];

  /// Checks preferences cache to return the user's manual market profile.
  /// Falls back to coordinates-based matching if personalization is enabled.
  static LocalMarketProfile? getActiveMarket() {
    final box = GetStorage("preferences");
    final String? cachedId = box.read(_marketCacheKey);
    if (cachedId != null) {
      final market = findMarketById(cachedId);
      if (market != null) return market;
    }

    // Attempt matching from Location Preference Service region/country data
    final profile = UserPreferenceProfile.load();
    if (profile.locationFeatureEnabled && profile.region != null) {
      final market = searchMarkets(profile.region!).firstOrNull;
      if (market != null) {
        box.write(_marketCacheKey, market.id);
        return market;
      }
    }

    return null;
  }

  /// Sets the manual active market ID
  static Future<void> setActiveMarket(String marketId) async {
    final box = GetStorage("preferences");
    await box.write(_marketCacheKey, marketId);
  }

  /// Reset manual active market ID
  static Future<void> resetActiveMarket() async {
    final box = GetStorage("preferences");
    await box.remove(_marketCacheKey);
  }

  /// Find market by ID
  static LocalMarketProfile? findMarketById(String marketId) {
    try {
      return supportedMarkets.firstWhere((m) => m.id == marketId);
    } catch (_) {
      return null;
    }
  }

  /// Find closest market to user coordinates
  static LocalMarketProfile? findClosestMarket(double lat, double lng) {
    LocalMarketProfile? closest;
    double minDistance = double.maxFinite;

    for (final market in supportedMarkets) {
      // Euclidean distance is suitable for regional approximations
      final dist = math.sqrt(
        math.pow(market.latitude - lat, 2) + math.pow(market.longitude - lng, 2),
      );
      if (dist < minDistance) {
        minDistance = dist;
        closest = market;
      }
    }

    // Require market to be relatively close (e.g. within 6 degrees) or return manual selection
    if (minDistance < 6.0) {
      return closest;
    }
    return null;
  }

  /// Returns nearby markets
  static List<LocalMarketProfile> getNearbyMarkets(String marketId) {
    final market = findMarketById(marketId);
    if (market == null) return [];

    final List<LocalMarketProfile> nearby = [];
    for (final id in market.nearbyMarkets) {
      final m = findMarketById(id);
      if (m != null) nearby.add(m);
    }
    return nearby;
  }

  /// Returns matching markets by query
  static List<LocalMarketProfile> searchMarkets(String query) {
    final clean = query.toLowerCase().trim();
    if (clean.isEmpty) return [];

    return supportedMarkets.where((m) {
      return m.displayName.toLowerCase().contains(clean) ||
          m.city.toLowerCase().contains(clean) ||
          m.state.toLowerCase().contains(clean);
    }).toList();
  }

  /// Curates local channels matching aliases inside the user's active playlist
  static List<ChannelLive> getLocalChannelsForCategory({
    required String categoryKey, // 'broadcast', 'news', 'sports', 'pbs', 'spanish', 'all'
    required LocalMarketProfile market,
    required List<ChannelLive> playlist,
  }) {
    if (playlist.isEmpty) return [];

    final List<ChannelLive> matches = [];

    // Filter playlist based on category key
    switch (categoryKey) {
      case 'broadcast':
        final allBroadcastAliases = market.stationAliases.values.expand((element) => element).toList();
        for (final channel in playlist) {
          final chName = (channel.name ?? '').toLowerCase();
          final isMatch = allBroadcastAliases.any((alias) =>
              chName == alias.toLowerCase() ||
              chName.contains(' ${alias.toLowerCase()} ') ||
              chName.startsWith('${alias.toLowerCase()} ') ||
              chName.endsWith(' ${alias.toLowerCase()}'));
          if (isMatch) matches.add(channel);
        }
        break;

      case 'news':
        for (final channel in playlist) {
          final chName = (channel.name ?? '').toLowerCase();
          // Check news aliases or if category matches news AND contains city/state or news aliases
          final matchesAlias = market.newsAliases.any((alias) {
            final lowerAlias = alias.toLowerCase();
            if (chName.contains(lowerAlias)) return true;
            final clean = lowerAlias.replaceAll('news', '').replaceAll('channel', '').trim();
            return clean.isNotEmpty && chName.contains(clean);
          });
          final isLocalNews = chName.contains('news') &&
              (chName.contains(market.city.toLowerCase()) || chName.contains(market.state.toLowerCase()));
          if (matchesAlias || isLocalNews) {
            matches.add(channel);
          }
        }
        break;

      case 'sports':
        for (final channel in playlist) {
          final chName = (channel.name ?? '').toLowerCase();
          final matchesAlias = market.sportsAliases.any((alias) => chName.contains(alias.toLowerCase()));
          if (matchesAlias) matches.add(channel);
        }
        break;

      case 'pbs':
        final pbsAliases = market.stationAliases['PBS'] ?? [];
        for (final channel in playlist) {
          final chName = (channel.name ?? '').toLowerCase();
          final isPbsMatch = pbsAliases.any((alias) =>
              chName == alias.toLowerCase() ||
              chName.contains(' ${alias.toLowerCase()} ') ||
              chName.startsWith('${alias.toLowerCase()} ') ||
              chName.endsWith(' ${alias.toLowerCase()}'));
          if (isPbsMatch) matches.add(channel);
        }
        break;

      case 'spanish':
        final spanishAliases = market.stationAliases['Spanish'] ?? [];
        for (final channel in playlist) {
          final chName = (channel.name ?? '').toLowerCase();
          final matchesAlias = spanishAliases.any((alias) => chName.contains(alias.toLowerCase())) ||
              market.spanishAliases.any((alias) => chName.contains(alias.toLowerCase()));
          if (matchesAlias) matches.add(channel);
        }
        break;

      case 'all':
      default:
        // Combine all matching categories
        final allBroadcastAliases = market.stationAliases.values.expand((element) => element).toList();
        final Set<String> matchedIds = {};

        for (final channel in playlist) {
          final chName = (channel.name ?? '').toLowerCase();
          final isBroadcast = allBroadcastAliases.any((alias) =>
              chName == alias.toLowerCase() ||
              chName.contains(' ${alias.toLowerCase()} ') ||
              chName.startsWith('${alias.toLowerCase()} ') ||
              chName.endsWith(' ${alias.toLowerCase()}'));

          final isNews = market.newsAliases.any((alias) => chName.contains(alias.toLowerCase())) ||
              (chName.contains('news') &&
                  (chName.contains(market.city.toLowerCase()) || chName.contains(market.state.toLowerCase())));

          final isSports = market.sportsAliases.any((alias) => chName.contains(alias.toLowerCase()));
          final isSpanish = (market.stationAliases['Spanish'] ?? []).any((alias) => chName.contains(alias.toLowerCase())) ||
              market.spanishAliases.any((alias) => chName.contains(alias.toLowerCase()));

          if (isBroadcast || isNews || isSports || isSpanish) {
            final id = channel.streamId ?? channel.name ?? '';
            if (id.isNotEmpty && !matchedIds.contains(id)) {
              matchedIds.add(id);
              matches.add(channel);
            }
          }
        }
        break;
    }

    // Deduplicate and rank results using basic confidence score
    final scored = matches.map((ch) {
      final name = (ch.name ?? '').toLowerCase();
      double score = 0.0;

      // Local exact affiliate callsign matches gets highest score
      for (final list in market.stationAliases.values) {
        for (final alias in list) {
          final al = alias.toLowerCase();
          if (name == al) {
            score += 200;
          } else if (name.startsWith('$al ') || name.endsWith(' $al') || name.contains(' $al ')) {
            score += 150;
          }
        }
      }

      // City match
      if (name.contains(market.city.toLowerCase())) {
        score += 80;
      }
      // State match
      if (name.contains(market.state.toLowerCase())) {
        score += 30;
      }
      // HD/FHD gets boost
      if (name.contains('hd') || name.contains('fhd') || name.contains('1080')) {
        score += 10;
      }

      // If Atlanta, GA, apply explicit sorting priority
      if (market.id == "atlanta_ga") {
        score += ProviderCurationRules.getAtlantaLocalPriority(ch.name ?? '');
      }

      return MapEntry(ch, score);
    }).toList();

    scored.sort((a, b) => b.value.compareTo(a.value));
    return scored.map((e) => e.key).toList();
  }
}
