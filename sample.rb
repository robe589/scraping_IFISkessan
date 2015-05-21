#coding: utf-8
require 'bundler'
Bundler.require
require 'open-uri'
require 'pp' 
require 'date'
require 'csv'
require 'fileutils'

def main()
	getDateRenge=[Date.today,Date.today+31]#データ取得日及び表示日の範囲
	storagePath='csv/'#日付別の決算企業ファイルの保存パス
	readFileName='holdStockList.csv'
	isStdIoScreen=true
	logPath='log/log.txt'

	FileUtils.rm_rf('log')
	FileUtils.rm_rf('csv')
	Dir.mkdir('log')
	Dir.mkdir('csv')
	ioLog=File.open(logPath,"w")
	$stdout_old=$stdout.dup
	io=$stdout_old
	begin	
		showOpeningScreen(getDateRenge,isStdIoScreen,logPath)
		mode=gets.to_i
		case mode
		when 0 then#サイトから決算日を読み込み
			readDateToSite(getDateRenge,storagePath)
		when 1 then#保有銘柄の決算日を表示
			showHoldStock(getDateRenge,readFileName,io,storagePath)
		when 2 then#サイトから取得した全データを表示
			showAllData(getDateRenge,io,storagePath)	
		when 3 then#今日が決算日の会社を表示
			tmpGetDateRenge=getDateRenge.clone
			getDateRenge[0]=Date.today
			getDateRenge[1]=Date.today
			readDateToSite(getDateRenge,storagePath)
			showAllData(getDateRenge,io,storagePath)
			getDateRenge=tmpGetDateRenge
		when 4 then#開始日と終了日を設定
			#データ取得範囲を設定
			error=setupDateGetRange(getDateRenge)
			if error !=-1
				getDateRenge=error.dup
			end
		when 5 then#標準出力の切り替え
			if isStdIoScreen == true
				io=ioLog
				isStdIoScreen=false
				puts '標準入出力をログに切り替え'
			else
				io=$stdout_old
				isStdIoScreen=true
				puts '標準入出力を画面に切り替え'
			end
		when 6 then#ログ削除
			FileUtils.rm(logPath)
			File.open(logPath,"w").close()
		when 7 then#プログラムを終了
			break;
		else
			puts'もう一度選択しなおしてください'
			puts''
		end
	end while 1
	ioLog.close
end

def showOpeningScreen(getDateRenge,isStdIoScreen,logPath)
	str="\nモードを選択してください"
	strMode=['サイトからデータを取得',
			'保有銘柄の決算日一覧を表示',
			'取得した決算を全表示',
			'今日の決算を表示',
			'取得範囲を変更','標準出力を変更',
			'ログの削除(logPath:'+logPath+')','終了']
	puts str
	strMode.each_with_index do |str,i|
		puts i.to_s+':'+str
	end
	puts "\n日付範囲:"+getDateRenge[0].strftime("%Y%m%d")+"~"+getDateRenge[1].strftime("%Y%m%d")
	if isStdIoScreen==true
		puts '標準出力:スクリーン'
	else
		puts '標準出力:ログ path='+logPath
	end
end

def readDateToSite(getDateRenge,storagePath)
	Dir.glob(storagePath+"*").each do |file|
		File.delete file
	end
	saveKessanToCsv(getDateRenge,storagePath)
end

def showHoldStock(getDateRenge,readFileName,io,storagePath)
	begin
		tmpHoldStockList=CSV.read(readFileName)
	rescue Errno::ENOENT
		puts readFileName+'がありません'
		return -1
	end 
	tmpHoldStockList.delete_at(0)
	holdStockList=Array.new
	tmpHoldStockList.length.times do |i|
		holdStockList[i]=Hash.new
		holdStockList[i]['code']=tmpHoldStockList[i][0].to_i
		holdStockList[i]['isNot']=true;
	end
	error=searchCsv(getDateRenge,holdStockList,io,storagePath)
	if error==-1
		puts'先にデータを取得してください'
		return -1
	end
	#決算情報がなかった銘柄を表示
	holdStockList.each do |stock|
		if stock['isNot']==true
			io.puts("コード:"+stock['code'].to_s+"の決算情報はありません");
		end
	end
end

def showAllData(getDateRenge,io,storagePath)
	holdStockList=Array.new
	holdStockList[0]='all'
	error=searchCsv(getDateRenge,holdStockList,io,storagePath)	
	if error==-1
		puts'先にデータを取得してください'
		return -1
	end
end

def setupDateGetRange(nowGetDateRenge)
	puts('データ取得開始日を入力 入力例:20150516 or ±2')
	strStartDate=gets.chomp
	startDate=calcDate(nowGetDateRenge[0],strStartDate)
	if startDate ==-1
		return -1
	end
	puts('データ取得終了日を入力')
	strEndDate=gets.chomp
	endDate=calcDate(nowGetDateRenge[1],strEndDate)	
	if endDate== -1
		return -1
	end

	return [startDate,endDate]
end

def calcDate(nowGetDate,strInputDate)
	if strInputDate[0]=='+' or strInputDate[0]=='-' 
		calcDate=nowGetDate+strInputDate.to_i
	elsif strInputDate.length !=8 or strInputDate.length !=8
		puts '桁数が異常'
		return -1
	else 
		format='%Y%m%d'
		calcDate=DateTime.strptime(strInputDate,format)
	end
	
	return calcDate
end

def getHtmlData(url)	
	html=open(url).read
	doc=Nokogiri::HTML.parse(html,nil,'utf-8')
	#p doc.title

	return doc
end

def saveKessanToCsv(getDateRenge,storagePath)
	#現在日時を取得
	#dateNow=Date.today
	#getDate=dateNow
	startDate=getDateRenge[0]
	endDate=getDateRenge[1]
	isNextPage=false
	begin
		dateStr=startDate.strftime("%Y%m%d")
		page=1
		csv=CSV.open(storagePath+dateStr+'.csv','wb')
		begin
			isNextPage=false 
			url='http://kabuyoho.ifis.co.jp/index.php?action=tp1&sa=schedule&ym='+dateStr[0..5]+'&lst='+dateStr+'&pageID='+page.to_s
			p url
			doc=getHtmlData(url)
			
			#その日の決算銘柄をCSVに保存
			strXpath='//tr[@class="line"]';
			doc.xpath(strXpath).each_with_index do |node,i|
				strXpath='./td/a'
				data=Array.new
				node.xpath(strXpath).each_with_index do |node,i|
					data[i]=node.text
				end	
				csv<<data
			end
			page+=1
			doc.xpath('//a[@title="next page"]').each do |node|
				isNextPage=true
			end
		end while isNextPage==true
		csv.close
		startDate+=1#次の日に
	end while startDate <= endDate
end

def searchCsv(getDateRange,searchStockList,io,storagePath)
	startDate=getDateRange[0]
	endDate=getDateRange[1]

	if searchStockList[0] =='all'
		isShowAll =true
	else
		isShowAll =false
	end

	begin
		isDayShowItem=false
		dateStr=startDate.strftime("%Y%m%d")
		#検索"
		begin 
			csv=CSV.open(storagePath+dateStr+'.csv',"r") 
		rescue Errno::ENOENT
			return -1;
		end	
		csv.each do |row|
			if isShowAll==true
				isDayShowItem=printCompany(isDayShowItem,io,dateStr,row)
			else	
				searchStockList.each do |search|
					if row[0].to_i ==search['code']#見つかった
						isDayShowItem=printCompany(isDayShowItem,io,dateStr,row)
						search['isNot']=false
					end
				end
			end
		end
		csv.close
		startDate+=1
	end while startDate <= endDate
end

def printCompany(isDayShowItem,io,dateStr,row)
	if isDayShowItem ==false 
		io.print "	~"+dateStr+"が決算~\n"
		isDayShowItem=true
	end
	io.print "コード:"+row[0] +"名称:"+row[1]+"\n"

	return isDayShowItem
end

main()
