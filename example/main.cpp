#include <fmt/core.h>

#include <openssl/evp.h>
#include <openssl/bio.h>
#include <openssl/err.h>


int main(int argc, char** argv)
{
    fmt::print("hello world\n");

    auto ctx = EVP_MD_CTX_new();
}
