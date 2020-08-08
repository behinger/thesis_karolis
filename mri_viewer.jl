using NIfTI
using Makie
scene = Scene()

ni = niread("c:/users/behinger/Downloads/full_cls_100um_2009b_sym.nii",mmap=true)


s1 = slider(LinRange(1, size(ni)[1], size(ni)[1]), raw = true, camera = campixel!, start = 500)
s2 = slider(LinRange(1,3,3), raw = true, camera = campixel!, start = 3)


y = lift((a,b) -> selectdim(ni,Int(ceil(b)),Int(ceil(a))),s1[end][:value],s2[end][:value])

p = heatmap(y)

final = hbox(p, vbox(s1,s2))#, parent = Scene(resolution = (1500, 1500)))
##
record(scene, "test.mp4", 500:1000; framerate = 60) do i
    x[] = i # update `t`'s value
end
