workflow Stop-VM  
{ 
    Param (  
        [parameter(Mandatory=$true)] 
        [String] 
        $VMName,   
        
        [parameter(Mandatory=$true)] 
        [String] 
        $ServiceName 
    )
    
    $day = (Get-Date).DayOfWeek
    if ($day -eq 'Saturday' -or $day -eq 'Sunday'){
        exit
    }  
    
    $subscriptionName = Get-AutomationVariable -Name "SubscriptionName" 
    $subscriptionID = Get-AutomationVariable -Name "SubscriptionID" 
    $certificateName = Get-AutomationVariable -Name "CertificateName" 
    $certificate = Get-AutomationCertificate -Name $certificateName  
    
    Set-AzureSubscription -SubscriptionName $subscriptionName -SubscriptionId $subscriptionID -Certificate $certificate 
    Select-AzureSubscription $subscriptionName  
    
    Stop-AzureVM -Name $VMName -ServiceName $ServiceName -Force
}