// Credentials are supplied on stdin from the retained QA secret, kept in memory,
// and redacted from failures. This script never writes or prints credentials.
const fs=require('node:fs');
const {chromium}=require(process.env.HOLYHER_PLAYWRIGHT||'playwright');
(async()=>{
 let raw='';for await(const chunk of process.stdin)raw+=chunk;
 const account=JSON.parse(raw);raw='';
 let browser,page;
 const report={qaOnly:true,customerAccountsModified:false,credentialsLogged:false,checks:[]};
 function pass(name){report.checks.push(name);console.log('PASS: '+name);}
 try{
  browser=await chromium.launch({headless:true,args:['--no-proxy-server']});
  const context=await browser.newContext({viewport:{width:1280,height:900},reducedMotion:'reduce'});
  page=await context.newPage();
  page.setDefaultTimeout(60000);
  async function ready(){await page.locator('#launch').waitFor({state:'detached',timeout:90000});const placeholder=page.locator('flt-semantics-placeholder');if(await placeholder.count())await placeholder.evaluate(element=>element.click());}
  await page.goto('http://127.0.0.1:4173/app/reading/1?from=saved&card=scripture');await ready();
  await page.getByRole('button',{name:/Already walking with us/}).click();
  await page.getByRole('textbox',{name:'Email',exact:true}).fill(account.email);
  await page.getByRole('textbox',{name:'Password',exact:true}).fill(account.password);
  await page.getByRole('button',{name:'Sign in',exact:true}).last().click();
  await page.getByText('Scripture · 1 of 5',{exact:true}).waitFor();
  pass('protected reading destination survives email sign-in');
  await page.getByRole('button',{name:'Close reading',exact:true}).click();
  await page.waitForURL('**/app/saved');pass('closing reading returns to Saved');
  console.log('Checking Saved search typing and history');await page.screenshot({path:'store/walk-redesign/browser-saved-before-search.png'});const search=page.getByRole('textbox',{name:'Search saved lessons',exact:true});await search.focus();await page.waitForTimeout(500);await search.fill('quiet');await page.waitForTimeout(300);if(await search.inputValue()!=='quiet')throw Error('Search input did not accept keyboard typing');console.log('Typed Saved query');await search.press('Tab');await page.waitForTimeout(300);if(await search.inputValue()!=='quiet')throw Error('Search text was lost on blur');
  console.log('Query retained after blur');await page.getByRole('button',{name:'Profile',exact:true}).last().click();await page.waitForURL('**/app/profile');console.log('Profile route opened');
  const backResponse=await page.goBack();console.log('Back document reload: '+Boolean(backResponse));console.log('Back route: '+new URL(page.url()).pathname);await page.waitForURL('**/app/saved');
  const restoredSearch=page.getByRole('textbox',{name:'Search saved lessons',exact:true});await restoredSearch.focus();await page.waitForTimeout(500);if(await restoredSearch.inputValue()!=='quiet')throw Error('Saved search state was lost');
  pass('browser back restores Saved tab and retained search');
  await page.goForward();await page.waitForURL('**/app/profile');await page.goBack();await page.waitForURL('**/app/saved');pass('browser Forward and Back restore the intended tabs');
  await page.goto('http://127.0.0.1:4173/app/reading/1?from=saved&card=scripture');await ready();await page.getByText('Scripture · 1 of 5',{exact:true}).waitFor();
  await page.reload();await ready();await page.getByText('Scripture · 1 of 5',{exact:true}).waitFor();pass('authenticated direct link survives refresh');
  await page.getByRole('button',{name:'Continue',exact:true}).last().click();await page.getByText('Meaning · 2 of 5',{exact:true}).waitFor();
  await page.screenshot({path:'store/walk-redesign/browser-authenticated-reading.png'});
  await page.goto('http://127.0.0.1:4173/app/reading/1?from=saved');await ready();await page.getByText('Meaning · 2 of 5',{exact:true}).waitFor();await context.setOffline(true);await page.reload();await ready();await page.getByText('Meaning · 2 of 5',{exact:true}).waitFor({timeout:90000});pass('cached account and unlocked reading reopen offline at the saved card');
  await context.setOffline(false);
  report.passed=true;
 }catch(error){let message=error.message;for(const value of [account.email,account.password])if(value)message=message.split(value).join('[redacted]');report.passed=false;report.failure=message;console.error(message);if(report.checks.includes('closing reading returns to Saved'))await page.screenshot({path:'store/walk-redesign/browser-account-failure.png'}).catch(()=>{});}
 finally{if(browser)await browser.close();fs.writeFileSync('store/walk-redesign/account-browser-qa.json',JSON.stringify(report,null,2)+'\n');}
 if(!report.passed)process.exitCode=1;
})().catch(()=>{console.error('Browser QA could not initialize. No credentials were logged.');process.exitCode=1;});
