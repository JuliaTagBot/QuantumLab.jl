"""
Although the BSE exposes a special SOAP-based API for programmatic access to its database, I had too much trouble getting the desired results from it. Therefore the solution in this module is based around regexing of the
human readable HTML output.
"""
module BasisSetExchangeModule

export obtainBasisSetExchangeEntries, downloadBasisSetBasisSetExchange, computeBasisSetExchangeEntry, BasisSetExchangeEntry
using HTTP
using Printf
using ..BasisSetModule
import Base.display, ..BasisSetModule.BasisSet

mutable struct BasisSetExchangeEntry
  url::String
  name::String
  availtype::String
  elts::String
  status::String
  hasEcp::String
  hasSpin::String
  lastModifiedDate::String
  contributionPI::String
  contributorName::String
  bsAbstract::String
end

function display(bseEntry::BasisSetExchangeEntry)
  @printf("%40s    |    %s\n", bseEntry.name, bseEntry.bsAbstract)
end

function display(arr::Array{BasisSetExchangeEntry,1})
  for entry in arr
    display(entry)
  end
end

function obtainBasisSetExchangeEntries()
  retval = Array{BasisSetExchangeEntry,1}()
  main = HTTP.request("GET","https://bse.pnl.gov:443/bse/portal/user/anon/js_peid/11543880926284/action/portlets.BasisSetAction/template/courier_content/panel/Main")
  for m in eachmatch(r"basisSets\[\d*\].*",String(main.body))
    bsline = m.match
    regmatch = match(r"basisSet\(\"(?P<url>.*)\", \"(?P<name>.*)\", \"(?P<type>.*)\", \"\[(?P<elts>.*)\]\", \"(?P<status>.*)\", \"(?P<hasEcp>.*)\", \"(?P<hasSpin>.*)\", \"(?P<lastModifiedDate>.*)\", \"(?P<contributionPI>.*)\", \"(?P<contributorName>.*)\", \"(?P<bsAbstract>.*)\"\)",bsline)
    eltsList = replace(regmatch[:elts],","=>"")
    push!(retval,BasisSetExchangeEntry(regmatch[:url],regmatch[:name],regmatch[:type],eltsList,regmatch[:status],regmatch[:hasEcp],regmatch[:hasSpin],regmatch[:lastModifiedDate],regmatch[:contributionPI],regmatch[:contributorName],regmatch[:bsAbstract]))
  end
  return retval
end

function downloadBasisSetBasisSetExchange(entry::BasisSetExchangeEntry, filename::AbstractString, format::AbstractString="TX93")
  requestresponse = HTTP.request("POST","https://bse.pnl.gov:443/bse/portal/user/anon/js_peid/11543880926284/action/portlets.BasisSetAction/template/courier_content/panel/Main/eventSubmit_doDownload/true",
				 ["Content-Type" => "application/x-www-form-urlencoded"],
				 HTTP.URIs.escapeuri(Dict("bsurl" => entry.url, "bsname" => entry.name, "elts" => entry.elts, "format" => format, "minimize" => "true")),
				 redirect=false)
  sessioncookie = String(match(r"JSESSIONID=(.*?);",Dict(requestresponse.headers)["Set-Cookie"])[1])
  finalresponse = HTTP.request("POST","https://bse.pnl.gov/bse/portal/user/anon/panel/Main/template/courier_content/js_peid/11543880926284"; cookies = Dict("JSESSIONID" => sessioncookie))
  basSetDef = replace(String(finalresponse.body),r".*<pre style.*>\n*(.*)</pre>.*"s => s"\1")
  outfd = open(filename, "w")
  write(outfd, basSetDef)
  close(outfd)
end

function computeBasisSetExchangeEntry(name::AbstractString, arr::Array{BasisSetExchangeEntry,1}; exactmatching::Bool=false)
  result = Nothing
  for entry in arr
    if (!exactmatching && occursin(Regex(name,"i"),entry.name) || name == entry.name)
      if result == Nothing
        result = entry
      elseif isa(result,BasisSetExchangeEntry)
        result = [result,entry]
      else #isa(result,Array{BasisSetExchangeEntry})
        push!(result,entry)
      end
    end
  end
  if result==Nothing
    error("$name is not contained within the given BasisSetExchangeEntry list.")
  end
  return result
end

"""
    BasisSet(name)

creates a BasisSet object from the specified file (possibly with a corresponding file extension).
If no such file can be found the argument is interpreted as the name of a basis set and that basis
set obtained from Basis Set Exchange.
"""
function BasisSet(name::AbstractString)
  if isfile(name)
    return readBasisSetTX93(name)
  end

  for ext in ("tx93", "TX93", "Tx93")
    if isfile("$name.$ext")
      return readBasisSetTX93("$name.$ext")
    end
  end

  info("BasisSet file not found locally. Obtaining from BasisSetExchange...")
  bseentries = obtainBasisSetExchangeEntries()
  entry = computeBasisSetExchangeEntry(name,bseentries;exactmatching=true)
  downloadBasisSetBasisSetExchange(entry,"$name.tx93","TX93")
  return readBasisSetTX93("$name.tx93")
end

end # module
