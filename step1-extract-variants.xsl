<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="2.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:tei="http://www.tei-c.org/ns/1.0"
    exclude-result-prefixes="xs tei">
  
  <xsl:output method="xml" indent="yes" encoding="UTF-8"/>
  
  <!-- Identity template: copy everything by default -->
  <xsl:template match="@*|node()">
    <xsl:copy>
      <xsl:apply-templates select="@*|node()"/>
    </xsl:copy>
  </xsl:template>
  
  <!-- Template for <l> element: filter out Sym.g and extract variants -->
  <xsl:template match="tei:l">
    <xsl:copy>
      <xsl:apply-templates select="@*"/>
      
      <!-- Collect all variant marker positions -->
      <xsl:variable name="markers" select="tei:w[@pos='Sym.g' and matches(., '^\s*＊[０１２３４５６７８９]+\s*$')]"/>
      
      <!-- Copy content excluding Sym.g and variant sections -->
      <xsl:for-each select="node()">
        <xsl:variable name="current" select="."/>
        
        <!-- Skip if this is a Sym.g element -->
        <xsl:if test="not(self::tei:w[@pos='Sym.g'])">
          
          <!-- Check if this element is inside any variant section -->
          <xsl:variable name="is-in-variant" as="xs:boolean">
            <xsl:choose>
              <xsl:when test="count($markers) = 0">
                <xsl:value-of select="false()"/>
              </xsl:when>
              <xsl:otherwise>
                <xsl:variable name="checks" as="xs:boolean*">
                  <xsl:for-each select="$markers">
                    <xsl:variable name="marker" select="."/>
                    <xsl:variable name="end-marker" select="$marker/following-sibling::tei:w[@pos='Sym.g'][1]"/>
                    
                    <xsl:choose>
                      <xsl:when test="$end-marker">
                        <!-- Check if current is between marker and end-marker -->
                        <xsl:value-of select="$current >> $marker and $current &lt;&lt; $end-marker"/>
                      </xsl:when>
                      <xsl:otherwise>
                        <!-- Check if current is after marker -->
                        <xsl:value-of select="$current >> $marker"/>
                      </xsl:otherwise>
                    </xsl:choose>
                  </xsl:for-each>
                </xsl:variable>
                <xsl:value-of select="some $c in $checks satisfies $c"/>
              </xsl:otherwise>
            </xsl:choose>
          </xsl:variable>
          
          <!-- Copy if not in variant section -->
          <xsl:if test="not($is-in-variant)">
            <xsl:apply-templates select="."/>
          </xsl:if>
        </xsl:if>
      </xsl:for-each>
      
      <!-- Extract variant rdg elements at the end -->
      <xsl:apply-templates select="$markers" mode="extract"/>
    </xsl:copy>
  </xsl:template>
  
  <!-- Extract mode: create <rdg> for variant sections -->
  <xsl:template match="tei:w[@pos='Sym.g']" mode="extract">
    <xsl:variable name="marker" select="."/>
    <xsl:variable name="marker-text" select="normalize-space(.)"/>
    
    <!-- Find the next Sym.g element (end marker) -->
    <xsl:variable name="end-marker" select="following-sibling::tei:w[@pos='Sym.g'][1]"/>
    
    <!-- Collect content between start marker and end marker -->
    <xsl:variable name="content" as="node()*">
      <xsl:choose>
        <xsl:when test="$end-marker">
          <!-- Elements after marker AND before end marker, using intersect -->
          <xsl:sequence select="(following-sibling::* intersect $end-marker/preceding-sibling::*)[not(self::tei:w[@pos='Sym.g'])]"/>
        </xsl:when>
        <xsl:otherwise>
          <!-- All following siblings if no end marker, excluding Sym.g -->
          <xsl:sequence select="following-sibling::*[not(self::tei:w[@pos='Sym.g'])]"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    
    <!-- Extract reading string from content -->
    <xsl:variable name="reading-parts" as="xs:string*">
      <xsl:apply-templates select="$content" mode="extract-reading"/>
    </xsl:variable>
    <xsl:variable name="reading-string" select="string-join($reading-parts, '')"/>
    <xsl:variable name="reading-len" select="string-length($reading-string)"/>
    
    <!-- Generate <rdg> element -->
    <rdg xmlns="http://www.tei-c.org/ns/1.0" corresp="{$marker-text}" string="{$reading-string}" len="{$reading-len}">
      <xsl:sequence select="$content"/>
    </rdg>
  </xsl:template>
  
  <!-- Extract reading mode: extract KanjiReading from <w> elements -->
  <xsl:template match="tei:w" mode="extract-reading">
    <xsl:variable name="msd" select="@msd"/>
    <xsl:if test="contains($msd, 'KanjiReading=')">
      <xsl:variable name="after-kr" select="substring-after($msd, 'KanjiReading=')"/>
      <xsl:variable name="reading">
        <xsl:choose>
          <xsl:when test="contains($after-kr, '|')">
            <xsl:value-of select="substring-before($after-kr, '|')"/>
          </xsl:when>
          <xsl:otherwise>
            <xsl:value-of select="$after-kr"/>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:variable>
      <xsl:value-of select="$reading"/>
    </xsl:if>
  </xsl:template>
  
  <!-- Extract reading mode: for <app>, only process first <rdg> -->
  <xsl:template match="tei:app" mode="extract-reading">
    <xsl:apply-templates select="tei:rdg[1]" mode="extract-reading"/>
  </xsl:template>
  
  <!-- Extract reading mode: for <rdg>, process all child elements -->
  <xsl:template match="tei:rdg" mode="extract-reading">
    <xsl:apply-templates select="*" mode="extract-reading"/>
  </xsl:template>
  
  <!-- Extract reading mode: ignore Sym.g elements -->
  <xsl:template match="tei:w[@pos='Sym.g']" mode="extract-reading"/>
  
  <!-- Extract reading mode: ignore text nodes -->
  <xsl:template match="text()" mode="extract-reading"/>
  
</xsl:stylesheet>
