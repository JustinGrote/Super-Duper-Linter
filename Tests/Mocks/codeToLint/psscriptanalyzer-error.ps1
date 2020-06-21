function badscript {
    [CmdletBinding()]
    param (
        $Username = 'ShouldBeSecure',
        $Password = 'ShouldBeSecureString'
    )
    
    'should be bad'
}