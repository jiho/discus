a = -10:10
# ac = circular(a,units="degrees",template="none")
ac = circular(a,units="degrees",template="geographic")

mean.circular(ac)
var.circular(ac)
range.circular(ac)
rose.diag(ac,bins=40)

x <- conversion.circular(ac, units = "radians", zero = 0, rotation = "counter", modulo = "2pi")

r = range.circular(x)

conversion.circular(r,units="degrees",type="angles",modulo="asis",template="geographics",zero=0,rotation="clock")



# plots
plot.circular(c(0,1,2))
lines.circular(c(0,1,2),c(0.5,0.2,0.5))

ff <- function(x){x*0+0.05}
curve.circular(ff,from=c(0,1.2),to=c(1,2),add=TRUE)