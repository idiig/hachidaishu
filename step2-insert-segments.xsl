<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="2.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:tei="http://www.tei-c.org/ns/1.0"
    exclude-result-prefixes="xs tei">
  
  <xsl:output method="xml" indent="yes" encoding="UTF-8"/>
  
  <!-- Segment thresholds pattern: 5-7-5-7-7-5-7-5-7-7 -->
  <xsl:variable name="thresholds" select="(5,7,5,7,7,5,7,5,7,7)"/>
  
  <!-- Identity template: copy everything by default -->
  <xsl:template match="@*|node()">
    <xsl:copy>
      <xsl:apply-templates select="@*|node()"/>
    </xsl:copy>
  </xsl:template>
  
  <!-- Template for <l> element: insert <seg/> markers -->
  <xsl:template match="tei:l">
    <xsl:copy>
      <xsl:apply-templates select="@*"/>
      
      <!-- Process children with segment insertion -->
      <xsl:call-template name="process-with-segments">
        <xsl:with-param name="nodes" select="node()"/>
        <xsl:with-param name="position" select="1"/>
        <xsl:with-param name="count" select="0"/>
        <xsl:with-param name="segment-index" select="1"/>
      </xsl:call-template>
    </xsl:copy>
  </xsl:template>
  
  <!-- Recursive template to process nodes and insert segments -->
  <xsl:template name="process-with-segments">
    <xsl:param name="nodes" as="node()*"/>
    <xsl:param name="position" as="xs:integer"/>
    <xsl:param name="count" as="xs:integer"/>
    <xsl:param name="segment-index" as="xs:integer"/>
    
    <xsl:if test="$position &lt;= count($nodes)">
      <xsl:variable name="current" select="$nodes[$position]"/>
      
      <!-- Check if this is a bottom rdg (not inside app) -->
      <xsl:variable name="is-bottom-rdg" as="xs:boolean"
        select="boolean($current/self::tei:rdg and not($current/parent::tei:app))"/>
      
      <!-- Get kana count for current node -->
      <xsl:variable name="kana-count" as="xs:integer">
        <xsl:choose>
          <xsl:when test="$is-bottom-rdg">
            <xsl:value-of select="0"/>
          </xsl:when>
          <xsl:otherwise>
            <xsl:call-template name="get-kana-count">
              <xsl:with-param name="node" select="$current"/>
            </xsl:call-template>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:variable>
      
      <!-- Calculate new count -->
      <xsl:variable name="new-count" select="$count + $kana-count"/>
      
      <!-- Get current threshold -->
      <xsl:variable name="threshold-idx" select="(($segment-index - 1) mod 10) + 1"/>
      <xsl:variable name="threshold" select="$thresholds[$threshold-idx]"/>
      
      <!-- Check if we should insert segment after this node -->
      <xsl:variable name="should-insert-segment" as="xs:boolean"
        select="$count &lt; $threshold and $new-count >= $threshold and $kana-count > 0"/>
      
      <!-- Copy current node -->
      <xsl:apply-templates select="$current"/>
      
      <!-- Insert segment if needed -->
      <xsl:if test="$should-insert-segment">
        <seg xmlns="http://www.tei-c.org/ns/1.0"/>
      </xsl:if>
      
      <!-- Process next node -->
      <xsl:call-template name="process-with-segments">
        <xsl:with-param name="nodes" select="$nodes"/>
        <xsl:with-param name="position" select="$position + 1"/>
        <xsl:with-param name="count" select="if($should-insert-segment) then 0 else $new-count"/>
        <xsl:with-param name="segment-index" select="if($should-insert-segment) then $segment-index + 1 else $segment-index"/>
      </xsl:call-template>
    </xsl:if>
  </xsl:template>
  
  <!-- Get kana count from a node -->
  <xsl:template name="get-kana-count">
    <xsl:param name="node"/>
    
    <xsl:choose>
      <!-- Skip Sym.g elements -->
      <xsl:when test="$node/self::tei:w[@pos='Sym.g']">
        <xsl:value-of select="0"/>
      </xsl:when>
      
      <!-- For <w> elements, extract KanjiReading -->
      <xsl:when test="$node/self::tei:w">
        <xsl:variable name="msd" select="$node/@msd"/>
        <xsl:choose>
          <xsl:when test="contains($msd, 'KanjiReading=')">
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
            <xsl:value-of select="string-length($reading)"/>
          </xsl:when>
          <xsl:otherwise>
            <xsl:value-of select="0"/>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:when>
      
      <!-- For <app> elements, only count first <rdg> -->
      <xsl:when test="$node/self::tei:app">
        <xsl:variable name="first-rdg-count" as="xs:integer*">
          <xsl:for-each select="$node/tei:rdg[1]/*">
            <xsl:call-template name="get-kana-count">
              <xsl:with-param name="node" select="."/>
            </xsl:call-template>
          </xsl:for-each>
        </xsl:variable>
        <xsl:value-of select="sum($first-rdg-count)"/>
      </xsl:when>
      
      <!-- For other elements, return 0 -->
      <xsl:otherwise>
        <xsl:value-of select="0"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  
</xsl:stylesheet>
