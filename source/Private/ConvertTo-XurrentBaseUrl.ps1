function ConvertTo-XurrentBaseUrl
{
    [CmdletBinding()]
    [OutputType([hashtable])]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateSet('Demo', 'QA', 'Prod')]
        [string]
        $Environment
    )

    process
    {
        switch ($Environment)
        {
            'Prod'
            {
                return @{
                    BaseUrl    = 'https://api.xurrent.com/v1'
                    GraphQLUrl = 'https://graphql.xurrent.com'
                    OAuthUrl   = 'https://oauth.xurrent.com/token'
                }
            }
            'QA'
            {
                return @{
                    BaseUrl    = 'https://api.xurrent.qa/v1'
                    GraphQLUrl = 'https://graphql.xurrent.qa'
                    OAuthUrl   = 'https://oauth.xurrent.qa/token'
                }
            }
            'Demo'
            {
                return @{
                    BaseUrl    = 'https://api.xurrent-demo.com/v1'
                    GraphQLUrl = 'https://graphql.xurrent-demo.com'
                    OAuthUrl   = 'https://oauth.xurrent-demo.com/token'
                }
            }
        }
    }
}
