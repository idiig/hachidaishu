<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="2.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:tei="http://www.tei-c.org/ns/1.0"
    exclude-result-prefixes="xs tei">
  
  <xsl:output method="xml" indent="yes" encoding="UTF-8"/>
  
  <!-- Segment pattern: 5-7-5-7-7-5-7-5-7-7 (cycling) -->
  <xsl:variable name="segment-pattern" select="(5, 7, 5, 7, 7)"/>
  
  <!-- Identity template -->
  <xsl:template match="@*|node()">
    <xsl:copy>
      <xsl:apply-templates select="@*|node()"/>
    </xsl:copy>
  </xsl:template>
  
  <!-- Template for <l>: insert <seg/> markers -->
  <xsl:template match="tei:l">
    <xsl:copy>
      <xsl:apply-templates select="@*"/>
      
      <!-- Process children and insert segments -->
      <xsl:call-template name="process-with-segments">
        <xsl:with-param name="nodes" select="*"/>
        <xsl:with-param name="position" select="1"/>
        <xsl:with-param name="count" select="0"/>
        <xsl:with-param name="seg-index" select="1"/>
        <xsl:with-param name="pending-seg" select="false()"/>
      </xsl:call-template>
    </xsl:copy>
  </xsl:template>
  
  <!-- Recursive template to process nodes and insert segments -->
  <xsl:template name="process-with-segments">
    <xsl:param name="nodes" as="element()*"/>
    <xsl:param name="position" as="xs:integer"/>
    <xsl:param name="count" as="xs:integer"/>
    <xsl:param name="seg-index" as="xs:integer"/>
    <xsl:param name="pending-seg" as="xs:boolean"/>
    
    <xsl:if test="$position &lt;= count($nodes)">
      <xsl:variable name="current" select="$nodes[$position]"/>
      
      <!-- Check if this is a standalone rdg (bottom variant from step1) -->
      <xsl:variable name="is-bottom-rdg" select="local-name($current) = 'rdg' and not(parent::tei:app)" as="xs:boolean"/>
      
      <!-- Skip Sym.g and bottom rdg elements for counting -->
      <xsl:variable name="should-skip" select="$current/@pos = 'Sym.g' or $is-bottom-rdg" as="xs:boolean"/>
      
      <!-- Count kana for this element -->
      <xsl:variable name="kana-count" as="xs:integer">
        <xsl:choose>
          <xsl:when test="$should-skip">
            <xsl:value-of select="0"/>
          </xsl:when>
          <xsl:otherwise>
            <xsl:call-template name="count-kana">
              <xsl:with-param name="node" select="$current"/>
            </xsl:call-template>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:variable>
      
      <!-- New cumulative count -->
      <xsl:variable name="new-count" select="$count + $kana-count"/>
      
      <!-- Current threshold -->
      <xsl:variable name="threshold" select="$segment-pattern[(($seg-index - 1) mod count($segment-pattern)) + 1]"/>
      
      <!-- Check if we've reached the threshold -->
      <xsl:variable name="reached-threshold" select="not($should-skip) and $new-count >= $threshold" as="xs:boolean"/>
      
      <!-- Check if next non-skipped element has forbidden pos -->
      <xsl:variable name="next-forbidden" as="xs:boolean">
        <xsl:variable name="next-non-skipped" select="$nodes[position() > $position][not(@pos = 'Sym.g' or (local-name() = 'rdg' and not(parent::tei:app)))][1]"/>
        <xsl:value-of select="exists($next-non-skipped) and ($next-non-skipped/@pos = 'P.c.g' or $next-non-skipped/@pos = 'Aux')"/>
      </xsl:variable>
      
      <!-- Determine if we should insert seg after this element -->
      <xsl:variable name="should-insert-seg" as="xs:boolean">
        <xsl:choose>
          <!-- If we have a pending seg and current element is not forbidden pos -->
          <xsl:when test="$pending-seg and not($should-skip) and not($current/@pos = 'P.c.g' or $current/@pos = 'Aux')">
            <xsl:value-of select="true()"/>
          </xsl:when>
          <!-- If we just reached threshold and next element is not forbidden -->
          <xsl:when test="$reached-threshold and not($next-forbidden)">
            <xsl:value-of select="true()"/>
          </xsl:when>
          <xsl:otherwise>
            <xsl:value-of select="false()"/>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:variable>
      
      <!-- Determine new pending state -->
      <xsl:variable name="new-pending" select="$reached-threshold and $next-forbidden" as="xs:boolean"/>
      
      <!-- Copy current element -->
      <xsl:apply-templates select="$current"/>
      
      <!-- Insert seg if needed -->
      <xsl:if test="$should-insert-seg">
        <seg xmlns="http://www.tei-c.org/ns/1.0"/>
      </xsl:if>
      
      <!-- Recurse to next element -->
      <xsl:call-template name="process-with-segments">
        <xsl:with-param name="nodes" select="$nodes"/>
        <xsl:with-param name="position" select="$position + 1"/>
        <xsl:with-param name="count">
          <xsl:choose>
            <xsl:when test="$should-insert-seg">0</xsl:when>
            <xsl:otherwise><xsl:value-of select="$new-count"/></xsl:otherwise>
          </xsl:choose>
        </xsl:with-param>
        <xsl:with-param name="seg-index">
          <xsl:choose>
            <xsl:when test="$should-insert-seg"><xsl:value-of select="$seg-index + 1"/></xsl:when>
            <xsl:otherwise><xsl:value-of select="$seg-index"/></xsl:otherwise>
          </xsl:choose>
        </xsl:with-param>
        <xsl:with-param name="pending-seg" select="$new-pending or ($pending-seg and not($should-insert-seg))"/>
      </xsl:call-template>
    </xsl:if>
  </xsl:template>
  
  <!-- Count kana in an element -->
  <xsl:template name="count-kana">
    <xsl:param name="node"/>
    
    <xsl:choose>
      <!-- For <w> elements, extract KanjiReading -->
      <xsl:when test="local-name($node) = 'w'">
        <xsl:variable name="msd" select="$node/@msd"/>
        <xsl:variable name="reading">
          <xsl:call-template name="extract-kanji-reading">
            <xsl:with-param name="msd" select="$msd"/>
          </xsl:call-template>
        </xsl:variable>
        <xsl:value-of select="string-length($reading)"/>
      </xsl:when>
      
      <!-- For <app> elements, only count first <rdg> -->
      <xsl:when test="local-name($node) = 'app'">
        <xsl:variable name="first-rdg" select="$node/tei:rdg[1]"/>
        <xsl:call-template name="count-kana-in-rdg">
          <xsl:with-param name="rdg" select="$first-rdg"/>
        </xsl:call-template>
      </xsl:when>
      
      <xsl:otherwise>0</xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  
  <!-- Count kana in an <rdg> element -->
  <xsl:template name="count-kana-in-rdg">
    <xsl:param name="rdg"/>
    
    <xsl:variable name="total" as="xs:integer*">
      <xsl:for-each select="$rdg//*[local-name() = 'w' and not(@pos = 'Sym.g')]">
        <xsl:variable name="reading">
          <xsl:call-template name="extract-kanji-reading">
            <xsl:with-param name="msd" select="@msd"/>
          </xsl:call-template>
        </xsl:variable>
        <xsl:value-of select="string-length($reading)"/>
      </xsl:for-each>
    </xsl:variable>
    
    <xsl:value-of select="sum($total)"/>
  </xsl:template>
  
  <!-- Extract KanjiReading from msd attribute -->
  <xsl:template name="extract-kanji-reading">
    <xsl:param name="msd"/>
    
    <xsl:if test="contains($msd, 'KanjiReading=')">
      <xsl:variable name="after-kr" select="substring-after($msd, 'KanjiReading=')"/>
      <xsl:choose>
        <xsl:when test="contains($after-kr, '|')">
          <xsl:value-of select="substring-before($after-kr, '|')"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="$after-kr"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:if>
  </xsl:template>
  
</xsl:stylesheet>
