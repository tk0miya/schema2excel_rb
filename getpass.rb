require 'Win32API'

def getpass
  _getch = Win32API.new('crtdll','_getch',[],'L')

  password = ''
  while (!/[\r\n]/.match(ch = _getch.Call.chr))
    password += ch
  end
  print "\n"

  password
end

def password_prompt(account = nil)
  if account.nil?
    printf("Input password: ")
  else
    printf("Input password (%s): ", account)
  end

  getpass()
end

def authenticate(account, password = nil, tries = 3)
  ret = 0
  tries = 1  if password

  tries.times do
    passwd = password || password_prompt(account)
    if yield(passwd)
      ret = 1
      break
    end

    printf("Authentication failed.\n\n")  if password.nil?
  end

  if ret.zero?
    raise StandardError.new('Authentication failed.')
  end

  ret
end

if $0 == __FILE__
  printf("Warning: this is sample code. Your input will be shown at the end of sample.\n\n")

  pwd = password_prompt()
  printf("Your password is %s\n", pwd)
end
