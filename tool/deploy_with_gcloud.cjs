// Use an existing owner login without changing CLI accounts or writing tokens.
const {execFileSync}=require('node:child_process');
const path=require('node:path');
const fs=require('node:fs');
const executable=fs.realpathSync(execFileSync('which',['firebase'],{encoding:'utf8'}).trim());
const root=path.resolve(path.dirname(executable),'..');
process.env.GOOGLE_CLOUD_QUOTA_PROJECT='holyher-app-production';
const cli=require(root);
const token=execFileSync('gcloud',['auth','print-access-token','--account=iamirrf1@gmail.com','--verbosity=error'],{encoding:'utf8',stdio:['ignore','pipe','pipe']}).trim();
require(path.join(root,'apiv2')).setAccessToken(token);
const only=process.argv[2];
if(!only||!/^functions:[a-zA-Z0-9,:-]+$|^hosting$/.test(only))throw Error('Specify exact functions or hosting.');
cli.deploy({project:'holyher-app-production',cwd:process.cwd(),only,nonInteractive:true,user:{email:'iamirrf1@gmail.com'},tokens:{access_token:token,expires_at:Date.now()+3500000,scopes:[]}}).then(()=>console.log('Deployment finished.')).catch(error=>{console.error(error.message);process.exitCode=1;});
