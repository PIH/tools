// Find all concepts in a diagnosis concept set
//  which do NOT have a concept class of diagnosis

def candidates = []

concept.getConcept(7912).setMembers.each {
  candidates.addAll(it.setMembers)
}
candidates.unique()

candidates.each { c ->
  if (c.conceptClass.name != "Diagnosis") {
    println "Class ${ c.conceptClass.name } for <a target='_new' href='../../dictionary/concept.htm?conceptId=${ c.id }'>${c.name}</a>"
  }
}