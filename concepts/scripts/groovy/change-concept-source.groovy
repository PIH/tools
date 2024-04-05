def currentSourceName = 'MVP/CIEL at PIH' 
def newSourceName = 'CIEL' 
def newCode = '' 
def newUuid = '249b13c8-72fa-4b96-8d3d-b200efed985e'
def newDesc = 'Columbia International eHealth Laboratory concept ID'

source = org.openmrs.api.context.Context.getConceptService().getConceptSourceByName(currentSourceName); 
println "<p><b>Name: ${source.getConceptSourceId()} ${source.getName()}</b><br>"   

source.setName(newSourceName) 
source.setHl7Code(newCode) 
source.setUuid(newUuid)
source.setDescription(newDesc)

