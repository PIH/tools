// Clean up capitalized concept name
// Change to "Smart case" (i think)

def candidates = []

// put any concept ids that we want to ignore here
def skip = [ ]

// put ids of concept_names that we actually want to clean here (anything not here will be reported, but not modified)
def toChange = [ 7465, 7212, 7215, 7468, 7796, 7266, 7591, 16005, 6664, 7849, 7416, 6625, 7633, 7284, 6751, 7106, 7450, 8886, 12626,
  3348, 18680, 3349, 12627, 18681, 13505, 5354, 18683, 3352, 12630, 18684, 18685, 5070, 7183, 13224, 12814, 4657, 18686, 18687, 233,
  10146, 18688, 5208, 13362, 6764, 15776, 6687, 7091, 7006, 7103, 6420, 6849, 6812, 8970, 7899, 14662, 5635, 5637, 6979, 6643, 9423,
  7648, 6621, 6463, 7572, 6395, 6748, 6464, 3350, 6752, 6489, 12628, 18682, 6763, 6935, 15948, 7898, 7839, 6394, 18353, 7851, 7413, 7447 ]

def keepUppercase = [ "NOS", "HIV", "VIH", "TB", "STI" ] 

// looks at the "HUM Diagnosis Sets" set-of-sets and gets all members-of-members
concept.getConcept(7912).setMembers.each {
  candidates.addAll(it.setMembers)
}

candidates.unique()

def fixCasing = { s ->
  def temp = "" + Character.toUpperCase(s.charAt(0)) + s.substring(1).toLowerCase()
  keepUppercase.each {
    temp = java.util.regex.Pattern.compile("\\b${it.toLowerCase()}\\b", java.util.regex.Pattern.CASE_INSENSITIVE).matcher(temp).replaceAll(it)
  }
  return temp
}

def toReport = []

def done = []
def report = []

candidates.each { c ->
  def names = c.names.findAll { !it.voided }
  names.each {
    if (it.name.toUpperCase() == it.name) {
      if (toChange.contains(it.id)) {
        def before = it.name
        def after = fixCasing(before)
        it.name = after
        concept.saveConcept(it.concept)
        done << "${before} &rarr; ${after}"
      } else {     
        report << """<button onClick="\$j('#copy-target').val(\$j('#copy-target').val() + '${ it.id }, ')">Add</button> ${ it.id } - ${ it.name } (${ it.locale })"""
      }
    }
  }
}

if (done) {
  println "<div style='border: 1px black solid; background-color: white'><h3>Done</h3>"
  done.each { println it }
  println "</div>"
}

println "<h3>Others available to do</h3>"
println """<input id="copy-target" type="text" size="120"/>"""
report.each {
  println it
}
​