require "selenium-webdriver"
require "pry-rails"
require "csv"
require "date"

# ============= CSV読み込み ============================ 
csv_data     = CSV.read("CSV出力用.csv")
@start_member = "" # 誰から始めるか（最初から始める場合は空文字にしておく）
@last_member  = ""  # 誰まで実行するか（最後まで実行する場合は空文字にしておく)

# ============= 画面を開く ============================ 
options = Selenium::WebDriver::Chrome::Options.new
@driver = Selenium::WebDriver.for :chrome, options: options
@driver.navigate.to "https://atnd.ak4.jp/login"
@driver.manage.window.maximize
sleep 1

# ============= AKASHIログイン ============================ 
login_info = [{ form: 'form_company_id', env: ENV["AKASHI_ID"]      },
              { form: 'form_login_id'  , env: ENV["AKASHI_EMAIL"]   },
              { form: 'form_password'  , env: ENV["AKASHI_PASSWORD"]}]

login_info.each do |info|
  login_form = @driver.find_element(:id, info[:form])
  login_form.send_keys info[:env]
end

@driver.find_element(:name, "commit").click
sleep 1

# ============= 勤怠画面に遷移 ============================ 
month      = csv_data[0][5].to_i
link_keys  = [{ attr: :xpath, key: "//p[text()=\"シフト\"]"        },
              { attr: :xpath, key: "//a[text()=\"月次シフト\"]"     },
              { attr: :id   , key: "date_chooser"                 },
              { attr: :xpath, key: "//span[text()=\"#{month}月\"]"}]

link_keys.each do |link|
  shift_page = @driver.find_element(link[:attr],link[:key])
  shift_page.click
end

sleep 2

# ============= 名前検索 & シフトマーク用意 ============================ 
def shift_input(data)
  if data[0] == "TRUE"
    
    @driver.find_element(:xpath, "//p[text()=\"氏名\"]").click
    sleep 1

    search_form = @driver.find_element(:id, 'form_staff_name')
    search_form.clear
    search_form.send_keys @name[0]
    sleep 1

    search_results = @driver.find_elements(:class,"c-table-filter__list__item--suggest")
    @extra_names   = []

    search_results.each do |result|
      if result.displayed?
        checkbox = result.find_element(:tag_name,"input")
        @extra_names << result.find_element(:tag_name,"label").text if checkbox.selected? 
      end
    end

    name_btn  = @driver.find_element(:xpath, "//label[text()=\"#{@name}\"]")
    name_btn.click
    sleep 1
    
    if @extra_names != []
      @extra_names.each do |e_name| 
        @driver.find_element(:xpath, "//p[text()=\"氏名\"]").click
        @driver.find_element(:id, 'form_staff_name').click
        sleep 1

        extra_btn = @driver.find_element(:xpath, "//label[text()=\"#{e_name}\"]")
        extra_btn.click
        sleep 1
      end
    end

    mark_lists  = [{pattern: '公休'                 , mark: ["公"]            },
                   {pattern: '年次有給休暇'          , mark: ["有"]            },
                   {pattern: 'I（10時-19時）'        , mark: ["10", "外A"]     },
                   {pattern: 'K（11時-20時）'        , mark: ["11-20", "外B"]  },
                   {pattern: 'Q（11時-22時）【中抜け】', mark: ["11-13","11-22"]},
                   {pattern: 'O（13時-22時）'        , mark: ["14-22", "19-22", "外C", "入", "16-22"]}]
  
    mark_lists.each do |list|
      input(data, list[:pattern], list[:mark])
    end
  end 
end

# ============= シフト入力処理 ============================ 
def input(schedule, pattern, mark) 

  pattern_list = Selenium::WebDriver::Support::Select.new(@driver.find_element(:id, 'form_scheduled_template_id'))
  pattern_list.select_by(:text, pattern) 

  cells  = @driver.find_elements(:class,"js-shift-calender-template-selectable-cell")
  @judge = nil

  schedule.each_with_index do |shift, i|
    if mark.any?{|m| shift.include?(m)}
      target_cell = cells[i-3]
      @driver.action.move_to(target_cell).perform
      @driver.action.move_by(0, 50).click.perform
      @judge = i
    end
  end 

  unless @judge == nil
    apply  = @driver.find_element(:name, "button") 
    apply.click 
    sleep 1
  end
end

# ============= 終了処理 ============================ 
def end_input(data,n)

  if @last_num == n
    puts "--- All Green!! ---"
    exit
  elsif @name == @last_member 
    puts "LGTM ❀ #{@name}\n--- All Green!! ---"
    exit
  else 
    puts "LGTM ❀ #{@name}" unless @name == nil
  end
end

# ============= 読み込み開始位置 ============================ 
puts "--- start #{month}month --- "
csv_data.each_with_index do |data, n| # csvの行を1行ずつ、取り出し、入力していく。
  @name     = data[1]
  @last_num = csv_data.length-1

  if @start_member == ""
    shift_input(data)
    end_input(data,n)

  elsif @name == @start_member
    shift_input(data)
    # 次の人をstart_memmberに入れ、処理を回していく。
    @start_member = csv_data[n+1][1] unless csv_data[n+1] == nil
    end_input(data,n)

  else
    puts "skip ✈ #{@name}"
  end
end

