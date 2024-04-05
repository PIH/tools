// Copy all French diagnosis concept names to Haitian Kreyol
// This is written when there's a superset (7912) of diagnosis sets

// variables:  
//    diagnosis concept set (7912)
//    frLocale
//    htLocale

def candidates = []

// put any concept ids that we want to ignore here
def skip = [ ]

// looks at the "HUM Diagnosis Sets" set-of-sets and gets all members-of-members
concept.getConcept(7912).setMembers.each {
  candidates.addAll(it.setMembers)
}

candidates.unique()

def frLocale = new Locale("fr")
def htLocale = new Locale("ht")

def newHtName = { n ->
  def newName = new org.openmrs.ConceptName()
  newName.locale = htLocale;
  newName.name = n.name
  newName.conceptNameType = n.conceptNameType
  newName.localePreferred = n.localePreferred
  n.tags.collect { newName.addTag(it) }
  return newName
}

def traceOutput = []

candidates.each { c ->
  if (!skip.contains(c.id)) {
    def french = c.names.findAll { !it.voided && it.locale == frLocale }
    def creole = c.names.findAll { !it.voided && it.locale == htLocale }

    if (french && creole) {
      traceOutput << "Skipping ${c} because it already has ${creole.size()} Creole name(s)"
    } else if (!french) {
      println "Skipping ${c} because it has no French names"
    } else {
      // DO IT
      println "<div style='border: 1px black solid'><h3>Concept ${c}</h3>"
      french.each {
        c.addName(newHtName(it))
        println "Copied name: ${it.name} (${it.conceptNameType})" + (it.localePreferred ? " *pref*" : "")
      }
      concept.saveConcept(c)
      println "</div>"
    }

    "Done with ${c}"
  }
}

println "Done"

println "<button onClick=\"\$j('#traceOutput').show()\">Show trace output</button>"
println "<div id='traceOutput' style='display: none'>${traceOutput.join('<br/>')}</div>"
​