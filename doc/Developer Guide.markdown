# Developer guide for DISCUS

The code is mostly

* [Bash](http://en.wikipedia.org/wiki/Bash "Bash - Wikipedia, the free encyclopedia") to run the main program and call the others

* Java for the [ImageJ](http://rsbweb.nih.gov/ij/ "ImageJ") plugins

* [R](http://www.r-project.org/ "The R Project for Statistical Computing") for the correction of tracks and computation of statistics



## Resources

The code is commented thoroughly everywhere but there is no way around learning the language to really understand the details of the mechanisms.

### Bash

Most of the code was written while consulting the [Advanced Bash Scripting Guide](http://tldp.org/LDP/abs/html/ "") and googling around. For more novice programmers, the [Bash Guide for Beginners](http://tldp.org/LDP/Bash-Beginners-Guide/html/index.html "") is a good resource.

Within the Bash code there are calls to Unix utilities that have their own syntax such as `awk`, `grep`, `sed`, etc. All of them are thoroughly documented in their respective man pages. So one should type

	man awk
	
to open the manual page for `awk`. The man pages are displayed by `less` and the navigation follows its conventions. In particular arrows move up and down, space moves one page down, and search is activated by `/`. So you should type `/foo` to search for "foo" and highlight it in the man page, then press `n` to go the next match and `N` to go to the previous one. See

	man less

for details.

Of particular interest and complexity are regular expressions which allow to match virtually any combination of characters in any file and which are used here and there in the code. A good starting reference is in the [dedicated chapter](http://tldp.org/LDP/Bash-Beginners-Guide/html/chap_04.html "") of the Bash Guide for Beginners, or the appropriate section of the man page for `grep`

	man grep
	
which also refers to

	man re_format
	
for a more in depth description of the format.

### Java

There are very little complex Java constructions in the plugins code. What they do is mostly call some high level ImageJ objects. So the best reference is the [ImageJ API](http://rsbweb.nih.gov/ij/developer/api/ "ImageJ API"). Beyond that, one should remember that Java is object oriented so doing something usually means instantiating a new object and then calling one of its methods, which might seem to be a little backwards when coming from more imperative/scripting languages.

There is also a bit of macro code which is described in the [ImageJ Macro Language](http://rsbweb.nih.gov/ij/developer/macro/macros.html "Macro Language") guide.

### R

The most complex parts of DISCUS are probably in the R code, merely reflecting the fact that it is the language I am the most comfortable with. A good starting material to understand the syntax and particularities of the language is the [Introduction to R](http://cran.r-project.org/doc/manuals/R-intro.pdf ""). A more in depth approach to the language is the Advanced Topics section of [The R Guide](http://cran.r-project.org/doc/contrib/Owen-TheRGuide.pdf ""). The focus should really be on data manipulation, advanced syntax, and language tricks.

There is no point, however, in spending time on the usual statistical methods since all the statistics used here are non-standard circular statistics. For those consult the help of the R package "[circular](http://cran.r-project.org/web/packages/circular/index.html "CRAN - Package circular")" which is used to compute the circular statistics here, by issuing the command

	help(package="circular")
	
within R. In particular it references the book "[Topics in circular Statistics](http://www.amazon.com/Topics-Circular-Statistics-Rao-Jammalamadaka/dp/9810237782 "Amazon.com: Topics in Circular Statistics: S. Rao Jammalamadaka, A. Sengupta: Books")" (2001) S. Rao Jammalamadaka and A. SenGupta, World Scientific.

Similarly, none of the base plotting methods of R are used and all plotting is done through the much more powerful package "[ggplot2](http://had.co.nz/ggplot2/ "ggplot. had.co.nz")". The help on the website is really well done and a [book](http://www.amazon.com/gp/product/0387981403?ie=UTF8&amp;tag=hadlwick-20&amp;linkCode=as2&amp;camp=1789&amp;creative=390957&amp;creativeASIN=0387981403 "Amazon.com: ggplot2: Elegant Graphics for Data Analysis (Use R): Hadley Wickham: Books") by the author of the package is in production.

Finally, an important characteristic of R is that it is more of a functional language than MATLAB, Fortran, or C to which people are more often introduced. That is to say, most things are accomplished by *functions* rather than `for` loops. The package [plyr](http://had.co.nz/plyr/ "plyr. had.co.nz") (by the author of ggplot2) makes it very easy to apply a home made function to a specific subset of data. So where you would see

	for (i in 1:3) {
		do something to data[i]
	}

in another language, you usually see 

	llpy(data, function(x) { do something to x } )
	
in R. Plyr also has a good [introductory guide](http://had.co.nz/plyr/plyr-intro-090510.pdf "") written by its author.

<br/>
<br/>
<br/>

*Jean-Olivier Irisson* — 2009-07-02 15:22:54 

`irisson@normalesup.org`
