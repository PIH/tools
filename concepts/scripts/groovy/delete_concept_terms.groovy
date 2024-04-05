source=concept.getConceptSource(1);
allterms=concept.getConceptReferenceTerms("%%",source,0,500,true);
terms=null;

for (term in allterms) {
   terms=term concept.purgeConceptReferenceTerm(terms)
}
