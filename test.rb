require "selenium-webdriver"
require "pry-rails"
require "csv"
require "date"

# ============= CSV読み込み ============================ 
data_list = CSV.read("CSV出力.csv")

start_member = "" # 誰から始めるか（最初から始める場合は空文字にしておく）
last_member = ""  # 誰まで実行するか（最後まで実行する場合はhogeにしておく

# ============= 画面を開く ============================ 
options = Selenium::WebDriver::Chrome::Options.new
driver = Selenium::WebDriver.for :chrome, options: options
driver.navigate.to "https://atnd.ak4.jp/login"
driver.manage.window.maximize

# ============= AKASHIログイン ============================ 
sleep 1

company_input = driver.find_element(:id, 'form_company_id')
company_input.send_key ENV["AKASHI_ID"]

email_input = driver.find_element(:id, 'form_login_id')
email_input.send_keys ENV["AKASHI_EMAIL"]

password_input = driver.find_element(:id, 'form_password')
password_input.send_keys ENV["AKASHI_PASSWORD"]

login_btn = driver.find_element(:name, "commit")
login_btn.click

# ============= 勤怠画面に遷移 ============================ 
sleep 1

shift_link = driver.find_element(:xpath, "//p[text()=\"シフト\"]")
shift_link.click

shift_link = driver.find_element(:xpath, "//a[text()=\"月次シフト\"]")
shift_link.click

shift_link = driver.find_element(:id, 'date_chooser')
shift_link.click

month = data_list[0][5].to_i
shift_link = driver.find_element(:xpath, "//span[text()=\"#{month}月\"]")
shift_link.click

# ============= シフトクリック処理 ============================ 
def input(driver, data, pattern, mark) 
  select = Selenium::WebDriver::Support::Select.new(driver.find_element(:id, 'form_scheduled_template_id'))
  select.select_by(:text, pattern) 
  shift_cells = driver.find_elements(:class,"js-shift-calender-template-selectable-cell")
  data.each_with_index do |shift, i|
    if mark.any?{|m| shift.include?(m)}
      cell = shift_cells[i-4]
      driver.action.move_to(cell).perform
      driver.action.move_by(0, 50).click.perform
    end
  end
  apply_link = driver.find_element(:name, "button")
  apply_link.click
  sleep 1
end

# ============= 名前検索 ▶ 入力処理 ============================ 
def shift_input(driver, data)
  if data[0] == "TRUE"
    name = data[1]
    name_link = driver.find_element(:xpath, "//p[text()=\"氏名\"]")
    name_link.click
    
    name_input = driver.find_element(:id, 'form_staff_name')
    name_input.clear
    name_input.send_keys name[0]
    
    name_btn = driver.find_element(:xpath, "//label[text()=\"#{name}\"]")
    name_btn.click
    sleep 5
    
    # 早番入力
    pattern = 'I（10時-19時）'
    mark = ["10", "14-19","外A"]

    input(driver, data, pattern, mark)

    # 中番入力
    pattern = 'K（11時-20時）'
    mark = ["11-20", "外B"]

    input(driver, data, pattern, mark)

    # 遅番入力
    pattern = 'O（13時-22時）'
    mark = ["14-22", "19-22", "中14-19", "外C"]

    input(driver, data, pattern, mark)

    # 中抜け入力
    pattern = 'P（11時-22時）【中抜け】'
    mark = ["11-22"]

    input(driver, data, pattern, mark)

    # 公休日入力
    pattern = '公休'
    mark = ["公"]

    input(driver, data, pattern, mark)

    # 有休日入力
    pattern = '年次有給休暇'
    mark = ["有"]

    input(driver, data, pattern, mark)

    # 特休日入力
    pattern = '【労務用】特別休暇'
    mark = ["特"]

    input(driver, data, pattern, mark)

  end 
end

# ============= 終了処理 ============================ 
def end_input(data, last_member)
  if data[1] == last_member 
    puts "#{data[1]}まで実行されたため終了します。"
    exit
  elsif last_member == ""
    puts "全ての処理は正常に完了しました。"
  end
end

# ============= 読み込み開始位置 ============================ 
puts "#{month}月分の入力を開始します"
data_list.each_with_index do |data, n| # csvの行を1行ずつ、取り出し、入力していく。

  if start_member == ""
    shift_input(driver, data)
    end_input(data, last_member)

  elsif data[1] == start_member
    shift_input(driver, data)
    end_input(data, last_member)
    start_member = data_list[n+1][1]   # 次の人をstart_memmberに入れ、処理を回していく。

  else
    puts "#{data[1]}の入力はskipしました"
  end
end

