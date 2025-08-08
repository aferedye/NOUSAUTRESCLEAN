<?php

namespace App\Controller\Api;

use App\Entity\User;
use Doctrine\ORM\EntityManagerInterface;
use Lexik\Bundle\JWTAuthenticationBundle\Services\JWTTokenManagerInterface;
use Symfony\Bundle\FrameworkBundle\Controller\AbstractController;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\PasswordHasher\Hasher\UserPasswordHasherInterface;
use Symfony\Component\Routing\Annotation\Route;
use Symfony\Component\Security\Core\User\UserInterface;

#[Route('/api/v1/auth')]
class AuthController extends AbstractController
{
    public function __construct(
        private EntityManagerInterface $em,
        private UserPasswordHasherInterface $hasher,
        private JWTTokenManagerInterface $jwt
    ) {}

    #[Route('/login', name: 'api_login', methods: ['POST'])]
    public function login(Request $request): JsonResponse
    {
        $data = json_decode($request->getContent(), true) ?? [];
        $email = isset($data['email']) ? trim((string)$data['email']) : '';
        $password = isset($data['password']) ? (string)$data['password'] : '';

        if ($email === '' || $password === '') {
            return $this->json(['error' => 'email and password are required'], 422);
        }

        /** @var UserInterface|User|null $user */
        $user = $this->em->getRepository(User::class)->findOneBy(['email' => strtolower($email)]);
        if (!$user || !$this->hasher->isPasswordValid($user, $password)) {
            return $this->json(['error' => 'invalid credentials'], 401);
        }

        try {
            $token = $this->jwt->create($user);
            return $this->json([
                'token' => $token,
                'user'  => ['id' => $user->getId(), 'email' => $user->getUserIdentifier()],
            ]);
        } catch (\Throwable $e) {
            $payload = [
                'error' => 'jwt_create_failed',
                'message' => $e->getMessage(),
            ];
            if (($_ENV['APP_ENV'] ?? 'prod') === 'dev' && $e->getPrevious()) {
                $payload['previous'] = [
                    'type' => (new \ReflectionClass($e->getPrevious()))->getShortName(),
                    'message' => $e->getPrevious()->getMessage(),
                ];
            }
            return $this->json($payload, 500);
        }
    }
}