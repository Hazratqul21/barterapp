"""Run only against an explicitly named disposable auth audit database."""
import asyncio
from datetime import UTC, datetime, timedelta
from types import SimpleNamespace
import uuid
import httpx
import jwt
import pytest
from cryptography.hazmat.primitives.asymmetric import rsa
from fastapi import HTTPException
from sqlalchemy import select
from app.core.config import settings
from app.core.security import decode_token
from app.db.session import SessionLocal, engine
from app.main import app
from app.models.user import User
from app.services import login_credentials


def test_google_token_validation(monkeypatch):
    private = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    monkeypatch.setattr(settings, 'google_client_ids', ('test-client',))
    monkeypatch.setattr(login_credentials._keys, 'get_signing_key_from_jwt', lambda _: SimpleNamespace(key=private.public_key()))
    claims = {'sub': 'google-test-subject', 'email': 'test@gmail.com', 'email_verified': True,
              'iss': 'https://accounts.google.com', 'aud': 'test-client',
              'iat': datetime.now(UTC), 'exp': datetime.now(UTC) + timedelta(minutes=5)}
    async def check():
        valid = await login_credentials.google_identity(jwt.encode(claims, private, algorithm='RS256'))
        assert valid['sub'] == 'google-test-subject'
        for change in [{'aud': 'attacker-client'}, {'iss': 'https://attacker.invalid'}, {'email_verified': False}, {'exp': datetime.now(UTC)-timedelta(seconds=1)}]:
            with pytest.raises(HTTPException) as error:
                await login_credentials.google_identity(jwt.encode({**claims, **change}, private, algorithm='RS256'))
            assert error.value.status_code == 401
    asyncio.run(check())


def test_malformed_access_subject_is_unauthorized():
    bad = jwt.encode({'sub': 'not-uuid', 'typ': 'access', 'iat': datetime.now(UTC), 'exp': datetime.now(UTC)+timedelta(minutes=1)}, settings.jwt_secret, algorithm='HS256')
    with pytest.raises(HTTPException) as error:
        decode_token(bad, 'access')
    assert error.value.status_code == 401


def test_auth_flows(monkeypatch):
    if 'mab_auth_audit_' not in settings.database_url:
        pytest.skip('Requires isolated mab_auth_audit_* database; never production')
    async def run():
        transport = httpx.ASGITransport(app=app)
        async with httpx.AsyncClient(transport=transport, base_url='http://audit') as client:
            phone = '+998' + str(uuid.uuid4().int % 10**9).zfill(9)
            async def code():
                response = await client.post('/auth/otp/request', json={'phone': phone})
                assert response.status_code == 200, response.text
                return response.json()['debug_code']
            first = await code()
            latest = await code()
            assert (await client.post('/auth/otp/verify', json={'phone':phone,'code':first})).status_code == 400
            outcomes = await asyncio.gather(*[client.post('/auth/otp/verify', json={'phone':phone,'code':latest}) for _ in range(2)])
            assert sorted(r.status_code for r in outcomes) == [200,400]
            token = next(r.json()['access_token'] for r in outcomes if r.status_code == 200)
            headers = {'Authorization': 'Bearer '+token}
            password = 'long-audit-password-123'
            result = await client.post('/auth/password/set', headers=headers, json={'password': password})
            assert result.status_code == 200, result.text
            assert (await client.post('/auth/password/set', headers=headers, json={'password':password+'x','current_password':'wrong'})).status_code == 401
            result = await client.post('/auth/password/login', json={'identifier':phone,'password':password})
            assert result.status_code == 200, result.text
            refresh = result.json()['refresh_token']
            responses = await asyncio.gather(*[client.post('/auth/refresh',json={'refresh_token':refresh}) for _ in range(2)])
            assert sorted(r.status_code for r in responses) == [200,401]
            async with SessionLocal() as db:
                user = await db.scalar(select(User).where(User.phone == phone))
                assert user.password_hash.startswith('$argon2id$')
                assert password not in user.password_hash
            latest = await code()
            response = await client.post('/auth/password/reset',json={'phone':phone,'code':latest,'password':password+'new'})
            assert response.status_code == 200, response.text
            assert (await client.post('/auth/password/login',json={'identifier':phone,'password':password})).status_code == 401
            assert (await client.post('/auth/password/login',json={'identifier':phone,'password':password+'new'})).status_code == 200
            identifier = 'missing-'+uuid.uuid4().hex+'@example.com'
            failures = [(await client.post('/auth/password/login',json={'identifier':identifier,'password':'incorrect'})).status_code for _ in range(6)]
            assert failures == [401]*5+[429]
            from app.api import auth
            async def fake_identity(_):
                return {'sub': 'audit-'+uuid.uuid4().hex, 'email': uuid.uuid4().hex+'@gmail.com', 'given_name':'Audit','family_name':'User'}
            monkeypatch.setattr(auth, 'google_identity', fake_identity)
            response = await client.post('/auth/google',json={'id_token':'dummy-token-for-test-only'})
            assert response.status_code == 200, response.text
            me = await client.get('/me',headers={'Authorization':'Bearer '+response.json()['access_token']})
            assert me.status_code == 200, me.text
            assert me.json()['phone'] is None and me.json()['trust_score'] == 0
            monkeypatch.setattr(settings,'app_env','production')
            monkeypatch.setattr(settings,'eskiz_email','')
            monkeypatch.setattr(settings,'eskiz_password','')
            assert (await client.get('/auth/methods')).json()['phone'] is False
            assert (await client.post('/auth/otp/request',json={'phone':phone})).status_code == 503
            assert (await client.post('/auth/otp/verify',json={'phone':phone,'code':'123456'})).status_code == 503
        await engine.dispose()
    asyncio.run(run())
