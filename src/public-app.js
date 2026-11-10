import './config.js';
import {normalizeContent,renderPublic} from './shared.js';
import {apiEndpoint,apiPath,mountDocument,showFailure} from './runtime.js';
const nativeFetch=window.fetch.bind(window);
window.researchFetch=(path,options={})=>nativeFetch(apiEndpoint+apiPath(path),options);
try{
 const config=window.EXPERIMENT_CONFIG;
 const response=await nativeFetch(config.supabaseUrl+'/rest/v1/rpc/get_research_content',{method:'POST',headers:{'content-type':'application/json',apikey:config.supabasePublishableKey},body:'{}',signal:AbortSignal.timeout(12000)});
 if(!response.ok)throw Error('Could not load current wording.');
 const content=normalizeContent(await response.json());
 await mountDocument(renderPublic(content));const contact=document.querySelector('a[href^="mailto:"]');if(contact&&content.texts.c085)contact.href='mailto:'+content.texts.c085;window.initializeResearchSurvey();
}catch(_){showFailure('the experiment could not load. please try again shortly.');}
