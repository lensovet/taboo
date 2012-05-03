class LinkParser:

  def __init__(self):
    import sys
    try:
      self.seed = sys.argv[1]
    except IndexError:
      self.seed = 'bird'
  
  def main(self):
    print 'hello!'
    # we expect to find a seed.xml file in our working directory
    source = open('./%s.xml' % self.seed)
    # print source.read(100)
    import amara
    xmlobj = amara.parse(source)
    print xmlobj.articles.rendertime
    targets = xmlobj.xml_xpath(u"//target")
    for link in targets:
      print link
    
def start(name, attrs):
    if name == 'target':
      print 'linkage!'


if __name__ == "__main__":
  import sys
  sys.exit(LinkParser().main())