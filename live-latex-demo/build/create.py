# coding=utf-8
import mysql.connector
from mysql.connector import errorcode
import codecs
import collections

def loadLocalizationMessages( fileName ):
	with open(fileName) as f:
		lines = f.read().splitlines()

	result = dict()
		
	for line in lines:
		pair = line.split('=', 1)
		result[pair[0]] = unicode(pair[1], 'utf-8')
	return result
	
def getDbConnection( host, user, password, database ):
	try:
		connection = mysql.connector.connect(user=user, password=password, host=host, database=database, charset='utf8')
		return connection
	except mysql.connector.Error as err:
		if err.errno == errorcode.ER_ACCESS_DENIED_ERROR:
			print("Something is wrong with your user name or password")
		elif err.errno == errorcode.ER_BAD_DB_ERROR:
			print("Database does not exist")
		else:
			print(err)
	
def queryLanguages( connection, constants ):
	cursor = connection.cursor()
	query = ("SELECT language_grid AS grid, language_name AS name, language_constant AS constant FROM language")
	cursor.execute(query)
	
	result = dict()
	for (grid, name, constant) in cursor:
		result[name] = constants[constant] if constants.has_key(constant) else name
	
	cursor.close()
	
	result = collections.OrderedDict(sorted(result.items()))
	return result
	
def loadTemplate( fileName ):
	with codecs.open(fileName, 'r', 'utf-8') as file:
		content=file.read()	
	return content
	
def buildContent( constants, values, tableId, caption, valueWidth ):
	frame = loadTemplate('frame.template')
	item = loadTemplate('item.template')

	items = ''
	for key in values:
		tmp = item
		tmp = tmp.replace('##constant##', key.replace('_', '\_'))
		tmp = tmp.replace('##label##', values[key])
		items += tmp + '\n'
			
	frame = frame.replace('##valuewidth##', valueWidth)
	frame = frame.replace('##tableid##', tableId)
	frame = frame.replace('##caption##', unicode(caption, 'utf-8') )
	frame = frame.replace('##items##', items)
	return frame

def writeUTF8File( destination, fileName, content ):
	file = codecs.open(destination + fileName, 'w', 'utf-8')
	file.write(content)
	file.close()
	
def convertFileUTF8toLatin2( destination, sourceFileName, targetFileName ):
	sourceEncoding = 'utf-8'
	targetEncoding = 'iso-8859-2'
	source = open(destination + sourceFileName)
	target = open(destination + targetFileName, 'w')
	target.write(unicode(source.read(), sourceEncoding).encode(targetEncoding))
				
destination = './../generated/'
sourcePath = './../outer/source/'		
		
connection = getDbConnection('localhost', 'root', 'root', 'texdb')	
constants = loadLocalizationMessages(sourcePath + 'locale/hu/messages.ini')

languages = queryLanguages(connection, constants)
content = buildContent(constants, languages, 'language_values', 'Nyelvek', 'c')
writeUTF8File(destination, 'language.utf8.tex', content)
convertFileUTF8toLatin2(destination, 'language.utf8.tex', 'language.latin2.tex')

connection.close()
