if (($# == 1)); then
	../../skynet/lua/lua luascript/makeconfig.lua $1
else
	echo "请输入程序名如(run.sh helloworld)"
fi