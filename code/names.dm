var/list/ai_names = file2list("config/names/ai.txt")
var/list/wizard_first = file2list("config/names/wizardfirst.txt")
var/list/wizard_second = file2list("config/names/wizardsecond.txt")
var/list/ninja_titles = file2list("config/names/ninjatitle.txt")
var/list/ninja_names = file2list("config/names/ninjaname.txt")
var/list/commando_names = file2list("config/names/death_commando.txt")
var/list/first_names_male = file2list("config/names/first_male.txt")
var/list/first_names_female = file2list("config/names/first_female.txt")
var/list/last_names = file2list("config/names/last.txt")
var/list/clown_names = file2list("config/names/clown.txt")
var/list/mush_first = file2list("config/names/mushman_first.txt")
var/list/mush_last = file2list("config/names/mushman_last.txt")
var/list/judge_male_names = file2list("config/names/judge_male.txt")
var/list/judge_female_names = file2list("config/names/judge_female.txt")

var/list/verbs = file2list("config/names/verbs.txt")
var/list/adjectives = file2list("config/names/adjectives.txt")
//loaded on startup because of "
//would include in rsc if ' was used

var/list/vox_name_syllables = list("cha","chi","ha","hi","ka","kah","ki","ta","ti","ya","ya","yi")
var/list/insectoid_name_syllables = list("biz","cree","chak", "chiz","drik","kaa","kek","khat","kit","ree","tak","tik","than","uz","xizz","xurr","zam","zax","zez","zin")
var/list/golem_names = file2list("config/names/golem.txt")
var/list/borer_names = file2list("config/names/borer.txt")
var/list/hologram_names = file2list("config/names/hologram.txt")

var/list/autoborg_silly_names = file2listExceptComments("config/names/autoborg_silly.txt")
