import { copyCatalog, copyRefs, normalizeContent, renderEditorPreview, validateTexts } from './shared.js';
const allowedOrigins=new Set(['https://reentangle.github.io','https://research.amongstudio.net','http://127.0.0.1:8781']);
const encoder=new TextEncoder();
export async function handle(request,env={get:name=>Deno.env.get(name)},fetcher=fetch){
 const origin=request.headers.get('origin')||'',url=new URL(request.url),path=url.pathname.replace(/^.*\/research-admin/,'')||'/';
 const cors={'access-control-allow-origin':origin,'access-control-allow-headers':'authorization, content-type, apikey','access-control-allow-methods':'GET, POST, DELETE, OPTIONS','vary':'Origin','cache-control':'no-store','x-content-type-options':'nosniff','referrer-policy':'no-referrer'};
 const reply=(data,status=200,type='application/json')=>new Response(type==='application/json'?JSON.stringify(data):data,{status,headers:{...cors,'content-type':type}});
 if(!allowedOrigins.has(origin))return new Response('Origin not allowed.',{status:403,headers:{'cache-control':'no-store'}});
 if(request.method==='OPTIONS')return new Response(null,{status:204,headers:cors});
 const base=env.get('SUPABASE_URL'),service=env.get('SUPABASE_SERVICE_ROLE_KEY');
 if(!base||!service)return reply({error:'Backend is not configured.'},503);
 async function rpc(name,params={}){const r=await fetcher(base+'/rest/v1/rpc/'+name,{method:'POST',headers:{'content-type':'application/json',apikey:service,authorization:'Bearer '+service},body:JSON.stringify(params),signal:AbortSignal.timeout(10000)});if(!r.ok)throw new Error('Database request failed.');return r.json();}
 async function loadContent(){const version=url.searchParams.get('version'),revision=url.searchParams.get('revision');if(version&&!/^v2\.[234]-r[1-9][0-9]*$/.test(version))throw Error('Invalid version.');return normalizeContent(await rpc(version?'get_research_content_by_version':'get_research_content',version?{p_version:version}:{p_revision:revision?Number(revision):null}));}
 try{
  if(path==='/count'&&request.method==='GET'){const count=await rpc('get_research_response_count');return Number.isSafeInteger(count)&&count>=0?reply({count}):reply({error:'Count unavailable.'},503);}
  if(path==='/login'&&request.method==='POST'){
   const body=await request.text();if(body.length>2000)return reply({error:'Invalid sign-in request.'},400);const {username,password}=JSON.parse(body);
   if(typeof username!=='string'||typeof password!=='string'||username.length>100||password.length>200)return reply({error:'Invalid username or password.'},400);
   // A single-admin global rate limit avoids collecting visitors' IP addresses.
   const digest=new Uint8Array(await crypto.subtle.digest('SHA-256',encoder.encode('github-admin|'+new Date().toISOString().slice(0,10))));
   const bucket=btoa(String.fromCharCode(...digest)).replace(/\+/g,'-').replace(/\//g,'_').replace(/=+$/,'');
   if(await rpc('github_consume_research_login_attempt',{p_reader_token:'service-role-only',p_bucket:bucket})!==true)return reply({error:'Too many sign-in attempts. Please try again in 15 minutes.'},429);
   if(!await rpc('github_admin_ready'))return reply({error:'Admin credentials require configuration.'},503);
   const token=await rpc('github_admin_login',{p_username:username,p_password:password});if(typeof token!=='string'||!/^[a-f0-9]{64}$/.test(token))return reply({error:'Invalid username or password.'},401);
   return reply({token,expires_at:Date.now()+12*60*60*1000});
  }
  const token=(request.headers.get('authorization')||'').replace(/^Bearer /,'');
  if(!/^[a-f0-9]{64}$/.test(token)||!await rpc('github_admin_session_valid',{p_token:token}))return reply({error:'Sign in required.'},401);
  if(path==='/logout'&&request.method==='POST'){await rpc('github_admin_logout',{p_token:token});return reply({success:true});}
  if(path==='/responses'&&request.method==='GET'){
   const version=url.searchParams.get('version'),reference=url.searchParams.get('reference');
   if(!version||(!['v1.0','v2.0','v2.1','unknown-legacy'].includes(version)&&!/^v2\.[234]-r[1-9][0-9]*$/.test(version)))return reply({error:'Unknown questionnaire version.'},400);
   if(reference&&!/^[A-F0-9]{8}$/.test(reference))return reply({error:'Invalid reference code.'},400);
   const rows=await rpc('github_get_private_responses',{p_reader_token:'service-role-only'});return reply(rows.filter(row=>reference?row.reference_code===reference:row.questionnaire_version===version));
  }
  const mutation=path.match(/^\/responses\/([1-9][0-9]{0,18})(\/restore)?$/);
  if(mutation&&request.method===(mutation[2]?'POST':'DELETE')){
   if(BigInt(mutation[1])>9223372036854775807n)return reply({error:'Invalid entry.'},400);
   if(!(request.headers.get('content-type')||'').startsWith('application/json'))return reply({error:'JSON required.'},415);
   const ok=await rpc('github_set_private_response_deleted',{p_reader_token:'service-role-only',p_response_id:mutation[1],p_deleted:!mutation[2]});return reply(ok?{success:true}:{error:'Entry not found.'},ok?200:404);
  }
  if(path==='/contacts'&&request.method==='GET')return reply(await rpc('github_get_private_conversation_contacts',{p_reader_token:'service-role-only'}));
  if(path==='/content'&&request.method==='GET')return reply({content:await loadContent(),catalog:copyCatalog,refs:copyRefs});
  if((path==='/content'||path==='/content/preview')&&request.method==='POST'){
   if(!(request.headers.get('content-type')||'').startsWith('application/json'))return reply({error:'JSON required.'},415);
   const text=await request.text();if(text.length>200000)return reply({error:'Text is too long.'},413);const body=JSON.parse(text);
   if(!validateTexts(body.texts)||!Number.isSafeInteger(body.revision)||body.revision<1)return reply({error:'Invalid text fields.'},400);
   if(path.endsWith('/preview')){const current=await rpc('get_research_content',{p_revision:body.revision});return reply(renderEditorPreview({...current,texts:body.texts}),200,'text/html; charset=utf-8');}
   const result=await rpc('github_save_research_content',{p_reader_token:'service-role-only',p_expected_revision:body.revision,p_texts:body.texts});
   if(result?.error==='conflict')return reply({error:'Someone saved newer text. Reload the editor before publishing.'},409);return reply(normalizeContent(result));
  }
  return reply({error:'Not found.'},404);
 }catch(_){return reply({error:'The request could not be completed. Please try again.'},502);}
}
if(typeof Deno!=='undefined')Deno.serve(request=>handle(request));
