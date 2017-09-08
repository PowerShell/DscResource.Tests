// Custom Attribute for determining the order a test should run in.
// Used to decorate a DSC configuration file with for example
// [Microsoft.DscResourceKit.IntegrationTest(OrderNumber = 1)].

using System;

namespace Microsoft.DscResourceKit
{
    // See the attribute guidelines at http://go.microsoft.com/fwlink/?LinkId=85236
    [System.AttributeUsage(System.AttributeTargets.All, Inherited = false, AllowMultiple = true)]
    public sealed class IntegrationTest : System.Attribute
    {
        public IntegrationTest() {}

        public int OrderNumber { get; set; }
    }
}

