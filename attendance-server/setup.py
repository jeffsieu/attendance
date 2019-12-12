import json, httplib, urllib

APPLICATION_ID = 'attendance'
MASTER_KEY = 'mySecretMasterKey'
REST_API_KEY = 'c0a7edd1-4481-4e16-b152-5e8db698543a'

def create_admin_role(connection):
    print('Creating admin role...')
    connection.request('POST', '/parse/roles', json.dumps({
       "name": "Admins",
       "ACL": {
         "*": {
           "read": True
         }
       }
     }), {
       "X-Parse-Application-Id": APPLICATION_ID,
       "X-Parse-REST-API-Key": REST_API_KEY,
       "Content-Type": "application/json"
     })
    result = json.loads(connection.getresponse().read())
    if result.get('error'):
        print('Role already exists')
    else:
        print('Success')

def create_master_admin_role(connection):
    print('Creating master admin role...')
    connection.request('POST', '/parse/roles', json.dumps({
       "name": "Master Admins",
       "ACL": {
         "*": {
           "read": True
         }
       }
     }), {
       "X-Parse-Application-Id": APPLICATION_ID,
       "X-Parse-REST-API-Key": REST_API_KEY,
       "Content-Type": "application/json"
     })
    result = json.loads(connection.getresponse().read())
    if result.get('error'):
        print('Role already exists')
    else:
        print('Success')

def create_master_admin_user(connection):
    print("Creating user with username 12345678, password adminpassword123")
    connection.request('POST', '/parse/users', json.dumps({
       "username": "12345678",
       "name": "Master Admin",
       "password": "adminpassword123",
     }), {
       "X-Parse-Application-Id": APPLICATION_ID,
       "X-Parse-REST-API-Key": REST_API_KEY,
       "X-Parse-Revocable-Session": "1",
       "Content-Type": "application/json"
     })

    result = json.loads(connection.getresponse().read())
    if result.get('error'):
        print('User already exists')
    else:
        print('Success')

def add_master_admin_user_role(connection):
    # Get user_id
    params = urllib.urlencode({"where":json.dumps({
       "username": "12345678",
     })})
    connection.request('GET', '/parse/users?%s' % params, '', {
       "X-Parse-Application-Id": APPLICATION_ID,
       "X-Parse-REST-API-Key": REST_API_KEY,
     })
    result = json.loads(connection.getresponse().read())
    user_id = result['results'][0]['objectId']
    print(result)

    # Get role_id
    params = urllib.urlencode({"where":json.dumps({
       "name": "Master Admins",
     })})
    connection.request('GET', '/parse/roles?%s' % params, '', {
       "X-Parse-Application-Id": APPLICATION_ID,
       "X-Parse-REST-API-Key": REST_API_KEY,
     })
    result = json.loads(connection.getresponse().read())
    role_id = result['results'][0]['objectId']

    connection.request('PUT', '/parse/roles/'+role_id, json.dumps({
       "users": {
         "__op": "AddRelation",
         "objects": [
           {
             "__type": "Pointer",
             "className": "_User",
             "objectId": user_id
           },
         ]
       }
     }), {
       "X-Parse-Application-Id": APPLICATION_ID,
       "X-Parse-Master-Key": MASTER_KEY,
       "Content-Type": "application/json"
     })
    result = json.loads(connection.getresponse().read())

def get_all_roles(connection):
    connection.request('GET', '/parse/roles/', '', {
       "X-Parse-Application-Id": APPLICATION_ID,
       "X-Parse-REST-API-Key": REST_API_KEY
     })
    return json.loads(connection.getresponse().read())

def verify_master_admin(connection):
    # Get user_id
    params = urllib.urlencode({"where":json.dumps({
       "username": "12345678",
     })})
    connection.request('GET', '/parse/users?%s' % params, '', {
       "X-Parse-Application-Id": APPLICATION_ID,
       "X-Parse-REST-API-Key": REST_API_KEY,
     })
    result = json.loads(connection.getresponse().read())
    user_id = result['results'][0]['objectId']

    params = urllib.urlencode({"where":json.dumps({
       "users": {
           "__type": "Pointer",
           "className": "_User",
           "objectId": user_id,
         },
     })})
    connection.request('GET', '/parse/roles?%s' % params, '', {
       "X-Parse-Application-Id": APPLICATION_ID,
       "X-Parse-REST-API-Key": REST_API_KEY,
     })
    result = json.loads(connection.getresponse().read())
    print("Successfully added master admin user" if 'Master Admins' in [role['name'] for role in result['results']] else "Failed to add master admin user")

def set_acl(connection):
    params = urllib.urlencode({"where":json.dumps({
       "name": "Admins",
     })})
    connection.request('GET', '/parse/roles?%s' % params, '', {
       "X-Parse-Application-Id": APPLICATION_ID,
       "X-Parse-REST-API-Key": REST_API_KEY,
     })
    result = json.loads(connection.getresponse().read())
    a_role_id = result['results'][0]['objectId']

    connection.request('PUT', '/parse/roles/'+a_role_id, json.dumps({
       "ACL": {
         "*": {
            "read": True,
            "write": False,
         },
         "role:Master Admins": {
            "read": True,
            "write": True,
         },
       }
     }), {
       "X-Parse-Application-Id": APPLICATION_ID,
       "X-Parse-Master-Key": MASTER_KEY,
       "Content-Type": "application/json"
     })
    result = json.loads(connection.getresponse().read())
    print(result)

    params = urllib.urlencode({"where":json.dumps({
       "name": "Master Admins",
     })})
    connection.request('GET', '/parse/roles?%s' % params, '', {
       "X-Parse-Application-Id": APPLICATION_ID,
       "X-Parse-REST-API-Key": REST_API_KEY,
     })
    result = json.loads(connection.getresponse().read())
    ma_role_id = result['results'][0]['objectId']

    connection.request('PUT', '/parse/roles/'+ma_role_id, json.dumps({
        "roles": {
          "__op": "AddRelation",
          "objects": [
            {
              "__type": "Pointer",
              "className": "_Role",
              "objectId": a_role_id,
            }
          ]
        },
       "ACL": {
         "*": {
            "read": True,
            "write": False,
         },
         "role:Master Admins": {
            "read": True,
            "write": True,
         },
       }
     }), {
       "X-Parse-Application-Id": APPLICATION_ID,
       "X-Parse-Master-Key": MASTER_KEY,
       "Content-Type": "application/json"
     })
    result = json.loads(connection.getresponse().read())
    print(result)


if __name__ == "__main__":
    connection = httplib.HTTPConnection('localhost', 1337)
    connection.connect()
    create_master_admin_role(connection)
    create_admin_role(connection)
    create_master_admin_user(connection)
    add_master_admin_user_role(connection)
    verify_master_admin(connection)
    set_acl(connection)