const BASE_URL = 'https://www.bdappsdigitalapps.com/NADB26088_Final';
const $ = (selector) => document.querySelector(selector);
const mobileInput = $('#mobile');
const otpForm = $('#otp-form');
const subscriptionForm = $('#subscription-form');
const status = $('#subscription-status');
let normalizedMobile = '';
let referenceNo = '';

document.querySelectorAll('.image-slot img').forEach((image) => {
  image.addEventListener('error', () => image.closest('.image-slot').classList.add('missing'));
});

function normalizeMobile(value) {
  let mobile = value.trim().replace(/[\s\-()]/g, '').replace(/^tel:/i, '').replace(/^\+/, '');
  if (/^01\d{9}$/.test(mobile)) mobile = `88${mobile}`;
  if (!/^8801\d{9}$/.test(mobile)) throw new Error('Enter a valid Bangladesh mobile number.');
  return mobile;
}

async function callProxy(path, fields) {
  const response = await fetch(`${BASE_URL}/${path}`, {
    method: 'POST', headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams(fields),
  });
  if (!response.ok) throw new Error('The subscription service is unavailable. Please try again.');
  const data = await response.json();
  if (!data || typeof data !== 'object') throw new Error('The subscription service returned an unexpected response.');
  return data;
}

function setStatus(message, isError = false) {
  status.textContent = message;
  status.style.color = isError ? '#a5482a' : '#4d7057';
}

subscriptionForm.addEventListener('submit', async (event) => {
  event.preventDefault();
  try {
    normalizedMobile = normalizeMobile(mobileInput.value);
    setStatus('Sending your OTP…');
    const data = await callProxy('send_otp.php', { user_mobile: normalizedMobile });
    referenceNo = String(data.referenceNo || '');
    if (String(data.statusCode || '').toUpperCase() !== 'S1000' || !referenceNo) throw new Error(data.statusDetail || 'Could not send the OTP.');
    subscriptionForm.classList.add('hidden');
    otpForm.classList.remove('hidden');
    $('#otp').focus();
    setStatus('OTP sent. Enter it to activate your subscription.');
  } catch (error) { setStatus(error.message, true); }
});

otpForm.addEventListener('submit', async (event) => {
  event.preventDefault();
  try {
    const otp = $('#otp').value.trim();
    if (!/^\d{4,8}$/.test(otp)) throw new Error('Enter the OTP sent to your mobile number.');
    setStatus('Verifying your subscription…');
    const data = await callProxy('verify_otp.php', { Otp: otp, referenceNo });
    const registered = String(data.subscriptionStatus || '').toUpperCase().replaceAll('.', '').trim() === 'REGISTERED';
    if (!registered) throw new Error(data.statusDetail || 'The OTP could not be verified.');
    setStatus('Subscription active. You can now open the Android app.');
  } catch (error) { setStatus(error.message, true); }
});

$('#check-subscription').addEventListener('click', async () => {
  try {
    normalizedMobile = normalizeMobile(mobileInput.value);
    setStatus('Checking your subscription…');
    const data = await callProxy('check_subscription.php', { user_mobile: normalizedMobile });
    const registered = String(data.subscriptionStatus || '').toUpperCase().replaceAll('.', '').trim() === 'REGISTERED';
    setStatus(registered ? 'Your subscription is active. You can open the Android app.' : 'No active subscription found. Tap Send OTP to subscribe.', !registered);
  } catch (error) { setStatus(error.message, true); }
});

$('#change-number').addEventListener('click', () => {
  referenceNo = ''; $('#otp').value = ''; otpForm.classList.add('hidden'); subscriptionForm.classList.remove('hidden'); setStatus(''); mobileInput.focus();
});

$('#unsubscribe-form').addEventListener('submit', async (event) => {
  event.preventDefault();
  const output = $('#unsubscribe-status');
  try {
    const mobile = normalizeMobile($('#unsubscribe-mobile').value);
    if (!window.confirm('Unsubscribe this mobile number from CatCare BD?')) return;
    output.textContent = 'Processing…';
    const data = await callProxy('unsubscribe.php', { user_mobile: mobile });
    const unregistered = String(data.subscriptionStatus || '').toUpperCase().replaceAll('.', '').trim() === 'UNREGISTERED';
    output.textContent = unregistered ? 'You have been unsubscribed successfully.' : (data.statusDetail || 'Could not unsubscribe.');
  } catch (error) { output.textContent = error.message; }
});
