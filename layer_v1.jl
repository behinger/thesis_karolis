##
using CSV
using Makie
using DataFrames
using Random
using ColorSchemes  
using TravelingSalesmanHeuristics
using Distances
using PDFIO
using AbstractPlotting
using GLMakie



## PDF Extraction
# code from https://github.com/sambitdash/PDFIO.jl
function getPDFText(src, out)
    # handle that can be used for subsequence operations on the document.
    doc = pdDocOpen(src)
    
    # Metadata extracted from the PDF document. 
    # This value is retained and returned as the return from the function. 
    docinfo = pdDocGetInfo(doc) 
    open(out, "w") do io
    
        # Returns number of pages in the document       
        npage = pdDocGetPageCount(doc)

        for i=1:npage
        
            # handle to the specific page given the number index. 
            page = pdDocGetPage(doc, i)
            
            # Extract text from the page and write it to the output file.
            pdPageExtractText(io, page)

        end
    end
    # Close the document handle. 
    # The doc handle should not be used after this call
    pdDocClose(doc)
    return docinfo
end

# Get Master Thesis and save it to txt file
getPDFText("../2020-08-03_Karolis.Degutis.Master.Thesis.pdf","thesis_txt.txt");
##
# read the extracted pdf text
f = open("thesis_txt.txt");
lines = readlines(f);
close(f);
# remove leading/trailing whitespaces
lines = strip.(lines);
# remove tabstops
lines = replace.(lines,"\t"=>" ");
# concat all lines
thesis_txt = string(lines...);
# had some troule with non-ascii characters. we will just remove them and hope nobody notice
thesis_txt = replace(thesis_txt, r"[^a-zA-Z0-9_ ]" => "");


##
# Now the Layer-Data comes in.
# 1. Select points in slice
# 2. solve travelling-salesman-problem to sort the text along the slice
# 3. interpolate middle-sized gaps
d_all = DataFrame()
for layer = 1:5
    # import layer. found at 
    # ftp://bigbrain.loris.ca/BigBrainRelease.2015/Layer_Segmentation/3D_Surfaces/
    d = CSV.read("c:/users/behinger/Downloads/masked_surfs_april2019_combined_20_layer$layer.obj",delim=" ",header=0,skipto=2,limit=1313051,threaded=false)
    # I should have renamed the columns directly, but I did not. Oops.
    deletecols!(d,:Column1)
    d =dropmissing(d)
    # which slice (actual dimension afaik in mm) to select
    lim = 15.85
    # how thick is the slice/slab?
    tol = 0.1
    ix = (d.Column4 .< lim+tol).&(d.Column4 .> lim-tol)
    d_short = d[ix,[:Column2, :Column3]]
 
    # 2. find shortest path
    r = pairwise(Euclidean(),Array(d_short[:,[:Column2,:Column3]]),dims=1)
    @time tmp = solve_tsp(r,quality_factor=20)

    # re-sort
    d_short = d_short[tmp[1],:]
    

    # 3. fill in gaps

    for r = (size(d_short,1)-1):-1:1
        x = d_short[[r,r+1],:Column2]
        y = d_short[[r,r+1],:Column3]
        d = sqrt((x[1]-x[2])^2 +(y[1]-y[2])^2)

        # now that we have the distance between sorted points, let's interpolate
        cutoff = 0.15 # we don't want to have too small distances
        cutoff_jump = 2.5 # we don't want to have too large gaps, else it happens often that gyri are "jumped"
        if (d < cutoff) || (d>cutoff_jump)
            continue
        else
         
        # interpolation range
        xnew = range(x[1],stop=x[2],length=Int64(ceil(d/cutoff)))
        ynew = range(y[1],stop=y[2],length=Int64(ceil(d/cutoff)))
        
        # new points along x/y
        d_new = DataFrame(Column2=xnew[2:end-1],Column3 = ynew[2:end-1])
        
        # concat
        d_short = vcat(d_short[1:r,:], d_new, d_short[(r+1):end,:])
        end
    end

    # add which layer we currently working on
    d_short[!,:layer] .= layer

    append!(d_all,d_short)
end

##
# extract x,y, calculate rotation, extract colors per layer
x = d_all.Column2
y = d_all.Column3
rot = vcat(0,atan.(x[1:end-1]-x[2:end],y[1:end-1]-y[2:end])).+π/2
colors = ColorSchemes.RdYlBu_5.colors[d_all.layer][end:-1:1];

# I had a bug in Makie, where no new Makie window opened if I did not do this. Maybe this is due to the svg export
GLMakie.activate!()

# Open up a scene, resolution doesn't really matter because I redefine it at export
scene = Scene(resolution = (2000, 1000))

# We could also use "scatter" wiht a hack to make the width's scale to the glyph's width. But this also works, it is 3x slower, but at 0.5s for 60.000 chars I am not complaining.
p = annotations!(string.(collect(thesis_txt[1:length(x)])),Point.(x,z),textsize=0.5,rotation=-rot,color=colors)

# At some point I added the label directly here, but I did it finally in illustrato
#annotations!(["Laminar fMRI at 3T:\nA replication attempt of top-down and bottom-up \nlaminar activity in the primary visual cortex"],[Point(0,-90)],color=:white,textsize=5,align=(:center,:center))
# make lims, approx square. 
xlims!((-60,60))
ylims!((-100,100))
p[:backgroundcolor] = :black

##
# sometimes it saves it correctly, other times... not. Strange. Output png is ~100mb!
Makie.save("./output.png",p,resolution=(5000,10000))

## So exporting to SVG also
using AbstractPlotting, CairoMakie
AbstractPlotting.current_backend[] = CairoMakie.CairoBackend("out.svg")
# save is broken, since it somehow defaults to png without checking the extension -.-
# but the below works to save a svg:
open("out.svg", "w") do io
    show(io, MIME"image/svg+xml"(), p)
end
